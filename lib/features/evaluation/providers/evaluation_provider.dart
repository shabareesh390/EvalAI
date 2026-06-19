import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/evaluation_model.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/gemini_service.dart';

enum EvaluationProviderStatus { initial, loading, success, error }

class EvaluationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();
  final Uuid _uuid = const Uuid();

  EvaluationProviderStatus _status = EvaluationProviderStatus.initial;
  String? _errorMessage;
  List<EvaluationModel> _evaluations = [];
  String _currentStep = '';

  EvaluationProviderStatus get status       => _status;
  String?                  get errorMessage => _errorMessage;
  List<EvaluationModel>    get evaluations  => _evaluations;
  bool                     get isLoading    =>
      _status == EvaluationProviderStatus.loading;
  String                   get currentStep  => _currentStep;

  // ── Save evaluation to Firestore ───────────────────────────────────────
  Future<bool> saveEvaluation({
    required ExamModel exam,
    required StudentModel student,
    required String teacherId,
    required ExamEvaluationResult result,
    required String extractedText,
    required double ocrConfidence,
  }) async {
    _setLoading('Saving evaluation...');
    try {
      final id = _uuid.v4();

      final evaluation = EvaluationModel(
        id: id,
        examId: exam.id,
        examName: exam.name,
        studentId: student.id,
        studentName: student.name,
        studentUsn: student.usn,
        studentRollNumber: student.rollNumber,
        teacherId: teacherId,
        totalMarksAwarded: result.totalMarksAwarded,
        totalMarks: result.totalMarks,
        overallFeedback: result.overallFeedback,
        questionResults: result.questionResults
            .map((r) => QuestionResult(
          questionNumber: r.questionNumber,
          marksAwarded: r.marksAwarded,
          totalMarks: r.totalMarks,
          strengths: r.strengths,
          weaknesses: r.weaknesses,
          missingConcepts: r.missingConcepts,
          suggestions: r.suggestions,
          aiConfidence: r.aiConfidence,
        ))
            .toList(),
        extractedText: extractedText,
        ocrConfidence: ocrConfidence,
        evaluatedAt: DateTime.now(),
      );

      await _firestoreService.saveEvaluation(evaluation);

      _evaluations.add(evaluation);
      _setSuccess();
      return true;
    } catch (e) {
      _setError('Failed to save evaluation: $e');
      return false;
    }
  }

  // ── Fetch evaluations for exam ─────────────────────────────────────────
  Future<void> fetchEvaluations(String examId) async {
    _setLoading('Loading evaluations...');
    try {
      _evaluations = await _firestoreService.fetchEvaluations(examId);

      _setSuccess();
    } catch (e) {
      _setError('Failed to fetch evaluations: $e');
    }
  }

  // ── UPGRADED: Direct Multimodal Evaluation with Gemini ──────────────────
  /// Sends the student's answer sheet file bytes directly to gemini-1.5-flash,
  /// avoiding errors caused by empty local OCR text extractions.
  Future<ExamEvaluationResult?> evaluate({
    required ExamModel exam,
    required Uint8List fileBytes,
    required String mimeType,
    required Function(String) onStepUpdate,
  }) async {
    try {
      _setLoading('Processing document...');
      onStepUpdate('Analyzing Handwriting...');
      
      // Allow UI to render the Analyzing step before starting the heavy networking task
      await Future.delayed(const Duration(milliseconds: 500));
      onStepUpdate('Grading...');

      final prefs = await SharedPreferences.getInstance();
      final aiLevel = prefs.getString('setting_ai_level') ?? 'Balanced';
      final spellCheck = prefs.getBool('setting_spell_check') ?? false;
      final spellCheckDeduction = prefs.getDouble('setting_spell_check_deduction') ?? 1.0;
      final negativeMarking = prefs.getBool('setting_negative_marking') ?? false;
      final graceMarks = prefs.getDouble('setting_grace_marks') ?? 0.0;

      // Make sure your GeminiService implementer matches this signature to accept bytes
      final result = await _geminiService.evaluateExamDirect(
        questions: exam.questions,
        fileBytes: fileBytes,
        mimeType: mimeType,
        aiLevel: aiLevel,
        spellCheck: spellCheck,
        spellCheckDeduction: spellCheckDeduction,
        negativeMarking: negativeMarking,
        graceMarks: graceMarks,
      );

      onStepUpdate('Evaluation complete!');
      _setSuccess();
      return result;
    } catch (e) {
      _setError('Evaluation failed: $e');
      return null;
    }
  }

  void _setLoading(String step) {
    _status = EvaluationProviderStatus.loading;
    _currentStep = step;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = EvaluationProviderStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = EvaluationProviderStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}