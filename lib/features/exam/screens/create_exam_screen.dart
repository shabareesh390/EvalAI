import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  bool _isProcessing = false;
  String _loadingStatus = 'AI is extracting data...';
  List<dynamic> _extractedQuestions = [];

  // Gemini API Key
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  String _getCleanErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('503') ||
        errorString.contains('high demand') ||
        errorString.contains('UNAVAILABLE')) {
      return 'Google AI servers are currently experiencing high demand. Please wait a few seconds and try again. â ³';
    } else if (errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup')) {
      return 'No internet connection found. Please check your network connection and try again. ðŸ“¶';
    } else if (errorString.contains('API key') || errorString.contains('400')) {
      return 'There is an issue with your Gemini API key configuration. Please verify your credentials. ðŸ”‘';
    } else if (errorString.contains('timeout')) {
      return 'The connection timed out. The PDF file may be too large or the internet connection is unstable. â ³';
    }

    return 'Failed to process document. Please verify the file structure and try again. ðŸ“„';
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
      _loadingStatus = 'AI is extracting data...';
    });

    try {
      final pdfBytes = result.files.single.bytes!;

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
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

      GenerateContentResponse? response;
      int maxRetries = 3;
      int attempts = 0;

      while (attempts < maxRetries) {
        try {
          response = await model.generateContent(prompt);
          break;
        } catch (e) {
          attempts++;
          if (attempts >= maxRetries) {
            rethrow;
          }

          setState(() {
            _loadingStatus = 'Server busy, securely retrying... ($attempts/$maxRetries)';
          });

          await Future.delayed(Duration(seconds: 2 * attempts));
        }
      }

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  Future<void> _saveExamToFirestore() async {
    String examName = '';
    String className = '';
    String subjectName = '';
    
    final formKey = GlobalKey<FormState>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Exam Details'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Exam Name',
                    hintText: 'e.g., Midterm Exam',
                  ),
                  onChanged: (val) => examName = val,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g., Physics',
                  ),
                  onChanged: (val) => subjectName = val,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    hintText: 'e.g., 10th A',
                  ),
                  onChanged: (val) => className = val,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (!mounted) return;
            Navigator.pop(context, true); 
                }
              },
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
      if (confirm == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields are required.')));
      }
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
            'keywords': q['keywords'] is Iterable
                ? List<String>.from((q['keywords'] as Iterable).map((k) => k.toString()))
                : <String>[],
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
          const SnackBar(content: Text('Exam saved successfully! ðŸŽ‰')),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_extractedQuestions.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withValues(alpha: 0.04),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 32),
                            Text(
                              'Upload Key Answer',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.displayMedium,
                            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 16),
                            Text(
                              'Our AI will automatically extract the question numbers, model answers, marks, and grading rubrics from your PDF.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 48),
                            CustomButton(
                              text: _isProcessing ? _loadingStatus : 'Select PDF File',
                              onPressed: _isProcessing ? () {} : _uploadAndParsePDF,
                              isLoading: _isProcessing,
                              icon: Icons.upload_file_rounded,
                            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extracted Questions',
                          style: AppTextStyles.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_extractedQuestions.length} items parsed',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    CustomButton(
                      text: 'Save Exam',
                      onPressed: _isProcessing ? () {} : _saveExamToFirestore,
                      isLoading: _isProcessing,
                      icon: Icons.check_circle_outline,
                      width: 140,
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: _extractedQuestions.length,
                    itemBuilder: (context, index) {
                      final q = _extractedQuestions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                            radius: 24,
                            child: Text(
                              q['question_number'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          title: Text(
                            q['model_answer'].toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Keywords: ${q['keywords'] is List ? (q['keywords'] as List).join(", ") : q['keywords']}',
                              style: AppTextStyles.caption,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${q['marks']}',
                                style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
                              ),
                              Text('Marks', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 100 * (index < 10 ? index : 0))).slideX(begin: 0.1, end: 0);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
