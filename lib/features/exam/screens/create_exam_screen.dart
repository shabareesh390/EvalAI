import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  bool _isProcessing = false;
  String _loadingStatus =
      'AI is extracting data...'; // NEW: Dynamic button text
  List<dynamic> _extractedQuestions = [];
  final _uuid = const Uuid();

  // Gemini API Key
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  String _getCleanErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('503') ||
        errorString.contains('high demand') ||
        errorString.contains('UNAVAILABLE')) {
      return 'Google AI servers are currently experiencing high demand. Please wait a few seconds and try again. ⏳';
    } else if (errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup')) {
      return 'No internet connection found. Please check your network connection and try again. 📶';
    } else if (errorString.contains('API key') || errorString.contains('400')) {
      return 'There is an issue with your Gemini API key configuration. Please verify your credentials. 🔑';
    } else if (errorString.contains('timeout')) {
      return 'The connection timed out. The PDF file may be too large or the internet connection is unstable. ⏳';
    }

    return 'Failed to process document. Please verify the file structure and try again. 📄';
  }

  Future<void> _uploadAndParsePDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _isProcessing = true;
      _loadingStatus = 'AI is extracting data...'; // Reset text on new attempt
    });

    try {
      final pdfBytes = result.files.single.bytes!;

      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final prompt = [
        Content.multi([
          TextPart('''
            Analyze the provided Key Answer PDF document. 
            Extract all questions/answers into a strict JSON array of objects.
            For each entry, extract:
            - "question_number": The question number as an integer.
            - "model_answer": The exact value points or answer provided.
            - "marks": The total marks for that specific question as an integer.
            - "keywords": A JSON array of 3-5 important strings from the answer used for grading.
            - "rubric": A string describing the marking breakdown if available.
            
            Return ONLY the raw JSON array.
          '''),
          DataPart('application/pdf', pdfBytes),
        ]),
      ];

      // ── INJECTED: Silent Exponential Backoff Auto-Retry Loop ──────────
      GenerateContentResponse? response;
      int maxRetries = 3; // Will try up to 3 times silently
      int attempts = 0;

      while (attempts < maxRetries) {
        try {
          response = await model.generateContent(prompt);
          break; // If successful, immediately break out of the retry loop
        } catch (e) {
          attempts++;
          if (attempts >= maxRetries) {
            rethrow; // If it fails 3 times, throw the error to the UI
          }

          // Silently update the UI so the user knows it hasn't frozen
          setState(() {
            _loadingStatus =
                'Server busy, securely retrying... ($attempts/$maxRetries)';
          });

          // Wait 2 seconds, then 4 seconds before hitting the server again
          await Future.delayed(Duration(seconds: 2 * attempts));
        }
      }
      // ─────────────────────────────────────────────────────────────────

      if (response?.text != null) {
        setState(() {
          String text = response!.text!;
          if (text.contains('```json')) {
            text = text.split('```json')[1].split('```')[0];
          } else if (text.contains('```')) {
            text = text.split('```')[1].split('```')[0];
          }
          _extractedQuestions = jsonDecode(text);
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint("Error parsing PDF: $e");
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  Future<void> _saveExamToFirestore() async {
    String examName = '';
    String className = '';
    String subjectName = '';

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Exam Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Exam Name (e.g., Midterm Exam)',
                ),
                onChanged: (val) => examName = val,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Subject (e.g., Physics)',
                ),
                onChanged: (val) => subjectName = val,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Class (e.g., 10th A)',
                ),
                onChanged: (val) => className = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirm != true ||
        examName.isEmpty ||
        className.isEmpty ||
        subjectName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required.')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _loadingStatus = 'Saving to database...';
    });

    try {
      final teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null) throw Exception("Teacher not logged in");

      int computedTotalMarks = 0;
      List<Map<String, dynamic>> formattedQuestions = [];

      for (var q in _extractedQuestions) {
        if (q is Map) {
          final int rawQuestionNum =
              int.tryParse(
                q['question_number']?.toString() ??
                    q['questionNumber']?.toString() ??
                    '0',
              ) ??
              0;
          final int rawMarks = int.tryParse(q['marks']?.toString() ?? '0') ?? 0;

          computedTotalMarks += rawMarks;

          formattedQuestions.add({
            'questionNumber': rawQuestionNum,
            'question_number': rawQuestionNum,
            'modelAnswer': q['model_answer'] ?? q['modelAnswer'] ?? '',
            'model_answer': q['model_answer'] ?? q['modelAnswer'] ?? '',
            'marks': rawMarks,
            'keywords': q['keywords'] ?? '',
          });
        }
      }

      final docRef = FirebaseFirestore.instance.collection('exams').doc();
      final currentDateString = DateTime.now().toString().split(' ')[0];

      await docRef.set({
        'id': docRef.id,
        'name': examName,
        'subject': subjectName,
        'totalMarks': computedTotalMarks,
        'date': currentDateString,
        'teacherId': teacherId,
        'className': className,
        'questions': formattedQuestions,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam saved successfully! 🎉')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Exam')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_extractedQuestions.isEmpty) ...[
              const Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Upload Key Answer PDF',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Our AI will automatically extract the question numbers, model answers, marks, and grading rubrics from your PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isProcessing ? _loadingStatus : 'Select PDF File',
                ), // FIXED: Dynamic label binding
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _isProcessing ? null : _uploadAndParsePDF,
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Extracted ${_extractedQuestions.length} Questions',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton.icon(
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save Exam'),
                    onPressed: _isProcessing ? null : _saveExamToFirestore,
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _extractedQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _extractedQuestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(q['question_number'].toString()),
                        ),
                        title: Text(
                          q['model_answer'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Keywords: ${q['keywords'] is List ? (q['keywords'] as List).join(", ") : q['keywords']}',
                        ),
                        trailing: Text(
                          '${q['marks']} Marks',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
