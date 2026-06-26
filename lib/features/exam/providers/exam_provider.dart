import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/question_model.dart';

enum ExamStatus { initial, loading, success, error }

/// Manages the state of exams, including creation and fetching from Firestore.
class ExamProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  ExamStatus _status        = ExamStatus.initial;
  String?    _errorMessage;
  List<ExamModel> _exams   = [];

  ExamStatus      get status       => _status;
  String?         get errorMessage => _errorMessage;
  List<ExamModel> get exams        => _exams;
  bool            get isLoading    => _status == ExamStatus.loading;

  /// Creates a new exam and saves it to Firestore.
  Future<bool> createExam({
    required String name,
    required String subject,
    required int totalMarks,
    required String date,
    required String teacherId,
    required String className,
    required List<QuestionModel> questions,
  }) async {
    _setLoading();
    try {
      final examId = _uuid.v4();

      final exam = ExamModel(
        id: examId,
        name: name,
        subject: subject,
        totalMarks: totalMarks,
        date: date,
        teacherId: teacherId,
        className: className,
        questions: questions,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection('exams')
          .doc(examId)
          .set(exam.toMap());

      _exams.add(exam);
      _setSuccess();
      return true;
    } catch (e) {
      _setError('Failed to create exam: $e');
      return false;
    }
  }

  /// Fetches exams for a specific teacher, gracefully skipping corrupted documents.
  Future<void> fetchExams(String teacherId) async {
    _setLoading();
    try {
      final snapshot = await _firestore
          .collection('exams')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .get();

      List<ExamModel> loadedExams = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          loadedExams.add(ExamModel.fromMap(data));
        } catch (documentError) {
          debugPrint("Skipping corrupted exam document [${doc.id}]: $documentError");
        }
      }

      _exams = loadedExams;
      _setSuccess();
    } catch (e) {
      _setError('Failed to fetch exams: $e');
    }
  }

  void _setLoading() {
    _status = ExamStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = ExamStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = ExamStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
