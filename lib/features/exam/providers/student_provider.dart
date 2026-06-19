import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/user_model.dart';

enum StudentStatus { initial, loading, success, error }

class StudentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  StudentStatus _status = StudentStatus.initial;
  List<StudentModel> _students = [];
  String? _errorMessage;

  StudentStatus      get status       => _status;
  List<StudentModel> get students     => _students;
  String?            get errorMessage => _errorMessage;
  bool               get isLoading    => _status == StudentStatus.loading;

  // ── Add Student ────────────────────────────────────────────────────────
  Future<bool> addStudent({
    required String name,
    required String usn,
    required String rollNumber,
    required String className,
    required String section,
    required String teacherId,
  }) async {
    _setLoading();
    try {
      final id = _uuid.v4();
      final student = StudentModel(
        id: id,
        name: name,
        usn: usn,
        rollNumber: rollNumber,
        className: className,
        section: section,
        teacherId: teacherId,
      );

      await _firestore
          .collection('students')
          .doc(id)
          .set(student.toMap());

      _students.add(student);
      _setSuccess();
      return true;
    } catch (e) {
      _setError('Failed to add student: $e');
      return false;
    }
  }
// ── Fetch Students (With Auto Document ID Injection) ───────────────────
  Future<void> fetchStudents(String teacherId) async {
    _setLoading();

    try {
      final snapshot = await _firestore
          .collection('students')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      List<StudentModel> loadedStudents = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // PERMANENT FIX: If the document map is missing an internal 'id' field,
          // inject the actual Firestore Document ID directly into the parser!
          if (data['id'] == null || data['id'].toString().isEmpty || data['id'] == 'null') {
            data['id'] = doc.id;
          }

          loadedStudents.add(StudentModel.fromMap(data));
        } catch (studentError) {
          debugPrint("Skipping invalid student profile [${doc.id}]: $studentError");
        }
      }

      _students = loadedStudents;
      _setSuccess();
    } catch (e) {
      _setError('Failed to fetch students: $e');
    }
  }

  // ── Delete Student ─────────────────────────────────────────────────────
  Future<void> deleteStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      _students.removeWhere((s) => s.id == studentId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete student: $e');
    }
  }

  void _setLoading() {
    _status = StudentStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = StudentStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = StudentStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}