import 'question_model.dart';

/// Represents a single exam and its associated questions.
class ExamModel {
  final String id;
  final String name;
  final String subject;
  final int totalMarks;
  final String date;
  final String teacherId;
  final String className;
  final List<QuestionModel> questions;
  final DateTime createdAt;

  ExamModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.totalMarks,
    required this.date,
    required this.teacherId,
    required this.className,
    required this.questions,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'totalMarks': totalMarks,
      'date': date,
      'teacherId': teacherId,
      'className': className,
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    return ExamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subject: map['subject'] ?? '',
      totalMarks: map['totalMarks'] ?? 0,
      date: map['date'] ?? '',
      teacherId: map['teacherId'] ?? '',
      className: map['className'] ?? map['className '] ?? map['class_name'] ?? '',
      questions: (map['questions'] as List<dynamic>?)
          ?.map((q) => QuestionModel.fromMap(q as Map<String, dynamic>))
          .toList() ??
          [],
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}