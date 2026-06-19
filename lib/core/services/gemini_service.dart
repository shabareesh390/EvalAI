import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/question_model.dart';

class EvaluationResult {
  final int questionNumber;
  final int marksAwarded;
  final int totalMarks;
  final String strengths;
  final String weaknesses;
  final String missingConcepts;
  final String suggestions;
  final double aiConfidence;

  final int marks;
  String get feedback => strengths;

  EvaluationResult({
    required this.questionNumber,
    required this.marksAwarded,
    required this.totalMarks,
    required this.strengths,
    required this.weaknesses,
    required this.missingConcepts,
    required this.suggestions,
    required this.aiConfidence,
  }) : marks = marksAwarded;

  double get percentage =>
      totalMarks > 0 ? (marksAwarded / totalMarks) * 100 : 0;
}

class ExamEvaluationResult {
  final List<EvaluationResult> questionResults;
  final int totalMarksAwarded;
  final int totalMarks;
  final String overallFeedback;

  ExamEvaluationResult({
    required this.questionResults,
    required this.totalMarksAwarded,
    required this.totalMarks,
    required this.overallFeedback,
  });

  double get percentage =>
      totalMarks > 0 ? (totalMarksAwarded / totalMarks) * 100 : 0;
}

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 8192,
      ),
    );
  }

  // ── THE SHIELD: Exponential Backoff ──────────────────────────
  Future<GenerateContentResponse> _generateContentWithRetry(
    List<Content> prompt,
  ) async {
    int maxRetries = 4;
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await _model.generateContent(prompt);
      } catch (e) {
        attempts++;
        final errorString = e.toString().toLowerCase();

        // If it's a quota issue, we try to wait it out
        if (errorString.contains('503') ||
            errorString.contains('unavailable') ||
            errorString.contains('quota') ||
            errorString.contains('429')) {
          FirebaseAnalytics.instance.logEvent(
            name: 'gemini_rate_limit_hit',
            parameters: {'attempt': attempts},
          );
          int waitTime = 10 * attempts; // Wait 10s, 20s, 30s...
          debugPrint(
            'API Traffic Limit! Retrying in $waitTime seconds... ($attempts/$maxRetries)',
          );
          if (attempts >= maxRetries) rethrow;
          await Future.delayed(Duration(seconds: waitTime));
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Failed to reach Gemini servers.');
  }

  // ── EXPERT EVALUATOR ENGINE ──────────────────────────
  Future<ExamEvaluationResult> evaluateExamDirect({
    required List<QuestionModel> questions,
    required Uint8List fileBytes,
    required String mimeType,
    String aiLevel = 'Balanced',
    bool spellCheck = false,
    double spellCheckDeduction = 1.0,
    bool negativeMarking = false,
    double graceMarks = 0.0,
  }) async {
    try {
      final blueprintList = questions
          .map(
            (q) => {
              "q": q.questionNumber,
              "marks": q.marks,
              "rubric": q.modelAnswer,
              "keywords": q.keywords,
            },
          )
          .toList();
      final blueprintJsonStr = jsonEncode(blueprintList);

      final prompt =
          '''
      You are an expert board-exam evaluator. Read the attached student answer sheet PDF/Image.

      EVALUATION STRICTNESS LEVEL: $aiLevel
      - If Strict: Deduct marks aggressively for missing keywords or minor errors.
      - If Balanced: Award partial marks fairly based on conceptual understanding.
      - If Lenient: Be generous; award marks if the core concept is present even if some keywords are missing.

      ${spellCheck ? 'SPELL CHECK ENABLED: Strictly deduct $spellCheckDeduction marks from the total for that question for spelling and grammatical errors.' : 'SPELL CHECK DISABLED: Ignore minor spelling mistakes as long as the meaning is clear.'}
      ${negativeMarking ? 'NEGATIVE MARKING ENABLED: If an answer is completely wrong, you may deduct -1 mark from the total, otherwise 0 for unattempted.' : 'NEGATIVE MARKING DISABLED: Do not award negative marks for wrong answers.'}

      EXAM BLUEPRINT (MASTER KEY):
      $blueprintJsonStr

      INSTRUCTIONS:
      1. Read the student's handwritten/typed answers from the document. Analyze any diagrams, graphs, and mathematical formulas carefully.
      2. Compare each answer conceptually to the EXAM BLUEPRINT.
      3. CRITICAL FOR 'OR'/'CHOICE' QUESTIONS: 
         - Identify which options the student actually attempted.
         - For unattempted alternative choices, set "marks" to 0, "applicable_total_marks" to 0, and explain in "feedback".
         - For attempted questions, set "applicable_total_marks" to the question's full marks.
      4. For MCQs, award full marks if the option letter or text matches.
      5. For descriptive answers, award partial marks if they hit some, but not all, keywords.
      6. MATHEMATICS & SCIENCE: Award step-wise partial marks for correct steps, formulas, and working, even if the final answer is incorrect.
      7. SI UNITS: Strictly check for correct SI units in final answers. Deduct marks if units are missing or incorrect.
      8. DIAGRAMS: Evaluate hand-drawn diagrams by analyzing labels, accuracy, and structure compared to the blueprint.
      9. Output a detailed JSON array containing the grades.

      REQUIRED JSON SCHEMA:
      [
        {
          "q": <question_number_as_int>,
          "marks": <marks_awarded_as_int>,
          "applicable_total_marks": <applicable_max_marks_as_int>,
          "feedback": "<detailed_feedback_explaining_why_marks_were_awarded_or_deducted>"
        }
      ]
      OUTPUT ONLY A RAW JSON ARRAY. Do not include markdown, greetings, or explanations outside the brackets.
      ''';

      final request = [
        Content.multi([TextPart(prompt), DataPart(mimeType, fileBytes)]),
      ];

      final response = await _generateContentWithRetry(request);
      return _processJsonAIResponse(
        response.text ?? '[]',
        questions,
        graceMarks,
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      String uiMessage = "SYSTEM ERROR: $e";

      FirebaseAnalytics.instance.logEvent(
        name: 'evaluation_failed',
        parameters: {
          'error_type': (errorStr.contains('quota') || errorStr.contains('429'))
              ? 'quota'
              : 'system_error',
        },
      );

      // Friendly message for Free Tier Quota Limits (No Emojis!)
      if (errorStr.contains('quota') || errorStr.contains('429')) {
        uiMessage =
            "RATE LIMIT REACHED: The Google Free Tier allows 15 requests per minute. Please wait 60 seconds and click Evaluate again.";
      }

      int total = questions.fold(0, (sum, q) => sum + q.marks);
      return ExamEvaluationResult(
        questionResults: [],
        totalMarksAwarded: 0,
        totalMarks: total,
        overallFeedback: uiMessage,
      );
    }
  }

  // ── JSON PARSER & MAPPING ──────────────────────────────────
  ExamEvaluationResult _processJsonAIResponse(
    String rawText,
    List<QuestionModel> questions,
    double graceMarks,
  ) {
    try {
      // Safe string cleaning without complex regex
      String cleanJson = rawText.trim();
      cleanJson = cleanJson.replaceAll('```json', '');
      cleanJson = cleanJson.replaceAll('```', '');
      cleanJson = cleanJson.trim();

      final startIndex = cleanJson.indexOf('[');
      final endIndex = cleanJson.lastIndexOf(']');

      if (startIndex == -1 || endIndex == -1) {
        throw FormatException('No JSON array found. AI Output: $rawText');
      }

      final validJsonStr = cleanJson.substring(startIndex, endIndex + 1);
      final List<dynamic> decodedList = jsonDecode(validJsonStr);
      final results = <EvaluationResult>[];

      for (final q in questions) {
        final matchedJson = decodedList.firstWhere(
          (item) => item['q']?.toString() == q.questionNumber.toString(),
          orElse: () => null,
        );

        if (matchedJson != null) {
          final marksAwarded =
              int.tryParse(matchedJson['marks']?.toString() ?? '0') ?? 0;
          final applicableTotal =
              int.tryParse(matchedJson['applicable_total_marks']?.toString() ?? '${q.marks}') ?? q.marks;
          final feedback =
              matchedJson['feedback']?.toString() ?? 'Graded successfully';

          results.add(
            EvaluationResult(
              questionNumber: q.questionNumber,
              marksAwarded: marksAwarded.clamp(0, applicableTotal),
              totalMarks: applicableTotal,
              strengths: feedback,
              weaknesses: '',
              missingConcepts: '',
              suggestions: '',
              aiConfidence: 90.0,
            ),
          );
        } else {
          results.add(
            EvaluationResult(
              questionNumber: q.questionNumber,
              marksAwarded: 0,
              totalMarks: q.marks,
              strengths: 'Question not found in student answer sheet.',
              weaknesses: 'Blank or missing.',
              missingConcepts: '',
              suggestions: 'Ensure all questions are attempted.',
              aiConfidence: 0,
            ),
          );
        }
      }

      final totalAwardedRaw = results.fold(0, (sum, r) => sum + r.marksAwarded);
      final totalMarks = results.fold(0, (sum, r) => sum + r.totalMarks);
      final totalAwarded = (totalAwardedRaw + graceMarks.round()).clamp(
        0,
        totalMarks,
      );

      // Local Feedback Generator
      final percentage = totalMarks > 0
          ? ((totalAwarded / totalMarks) * 100)
          : 0.0;
      String overallFeedback = 'Good effort! Keep practicing to improve.';
      if (percentage >= 90)
        overallFeedback =
            'Outstanding performance! You have an excellent grasp of the material.';
      else if (percentage >= 75)
        overallFeedback = 'Great job! You understand most concepts well.';
      else if (percentage >= 50)
        overallFeedback =
            'Good effort, but there is room for improvement in key conceptual areas.';
      else
        overallFeedback =
            'Needs improvement. Please review the missing concepts indicated in the feedback.';

      return ExamEvaluationResult(
        questionResults: results,
        totalMarksAwarded: totalAwarded,
        totalMarks: totalMarks,
        overallFeedback: overallFeedback,
      );
    } catch (e) {
      throw Exception('JSON Parsing Error: $e \nRaw AI Output: $rawText');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ── LEGACY PUBLIC METHODS (Kept to prevent compilation errors) ──
  // ══════════════════════════════════════════════════════════════════════
  Future<ExamEvaluationResult> evaluateExam({
    required List<QuestionModel> questions,
    required String extractedAnswerText,
  }) async {
    return ExamEvaluationResult(
      questionResults: [],
      totalMarksAwarded: 0,
      totalMarks: 100,
      overallFeedback: '',
    );
  }

  Future<EvaluationResult> evaluateQuestion({
    required QuestionModel question,
    required String studentAnswer,
  }) async {
    return EvaluationResult(
      questionNumber: 1,
      marksAwarded: 0,
      totalMarks: 1,
      strengths: '',
      weaknesses: '',
      missingConcepts: '',
      suggestions: '',
      aiConfidence: 0,
    );
  }

  String _buildEvaluationPrompt({
    required QuestionModel question,
    required String studentAnswer,
  }) => '';
  EvaluationResult _parseEvaluationResponse(
    String response,
    QuestionModel question,
  ) {
    return EvaluationResult(
      questionNumber: 1,
      marksAwarded: 0,
      totalMarks: 1,
      strengths: '',
      weaknesses: '',
      missingConcepts: '',
      suggestions: '',
      aiConfidence: 0,
    );
  }

  String _extractAnswerForQuestion(String fullText, int questionNumber) => '';
}
