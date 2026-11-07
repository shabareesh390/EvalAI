import 'package:flutter_test/flutter_test.dart';
import 'package:eval_ai/core/models/question_model.dart';
import 'package:eval_ai/core/models/evaluation_model.dart';
import 'package:eval_ai/core/models/user_model.dart';

void main() {
  group('QuestionModel Serialization Tests', () {
    test('handles standard question map correctly', () {
      final map = {
        'id': 'q1',
        'questionNumber': 1,
        'marks': 10,
        'modelAnswer': 'Cellular respiration produces ATP.',
        'keywords': ['ATP', 'respiration', 'mitochondria'],
        'rubric': 'Definition: 5 marks, equation: 5 marks',
      };

      final question = QuestionModel.fromMap(map);
      expect(question.id, 'q1');
      expect(question.questionNumber, 1);
      expect(question.marks, 10);
      expect(question.keywords.length, 3);
      expect(question.keywords.contains('ATP'), isTrue);
    });

    test('handles string keywords gracefully without throwing', () {
      // Regression test for Finding 5: AI JSON sometimes returns a string for keywords
      final map = {
        'id': 'q2',
        'questionNumber': 2,
        'marks': 5,
        'modelAnswer': 'Gravity pulls objects towards the earth center.',
        'keywords': 'gravity, earth',
        'rubric': '',
      };

      final question = QuestionModel.fromMap(map);
      expect(question.keywords, isA<List<String>>());
    });

    test('handles null and missing fields safely', () {
      final question = QuestionModel.fromMap({});
      expect(question.id, '');
      expect(question.questionNumber, 0);
      expect(question.marks, 0);
      expect(question.keywords, isEmpty);
    });
  });

  group('EvaluationModel Logic Tests', () {
    test('computes percentage, grade, and passing status accurately', () {
      final eval = EvaluationModel(
        id: 'eval_1',
        examId: 'exam_1',
        examName: 'Biology Midterm',
        studentId: 'stud_1',
        studentName: 'Alice',
        studentUsn: '1RV21CS001',
        studentRollNumber: '1',
        teacherId: 'teacher_1',
        totalMarksAwarded: 85,
        totalMarks: 100,
        overallFeedback: 'Great job!',
        questionResults: [],
        extractedText: 'sample text',
        ocrConfidence: 95.0,
        evaluatedAt: DateTime.now(),
      );

      expect(eval.percentage, 85.0);
      expect(eval.grade, 'A');
      expect(eval.isPassed, isTrue);
    });

    test('handles zero total marks without division by zero crash', () {
      final eval = EvaluationModel(
        id: 'eval_2',
        examId: 'exam_2',
        examName: 'Empty Exam',
        studentId: 'stud_2',
        studentName: 'Bob',
        studentUsn: '',
        studentRollNumber: '2',
        teacherId: 'teacher_1',
        totalMarksAwarded: 0,
        totalMarks: 0,
        overallFeedback: 'Empty',
        questionResults: [],
        extractedText: '',
        ocrConfidence: 0.0,
        evaluatedAt: DateTime.now(),
      );

      expect(eval.percentage, 0.0);
      expect(eval.grade, 'F');
      expect(eval.isPassed, isFalse);
    });
  });

  group('StudentModel Serialization Tests', () {
    test('parses roll number and class name formats', () {
      final map = {
        'id': 's1',
        'name': 'Charlie',
        'rollNumber': 42,
        'className': '10th B',
        'teacherId': 't1',
      };

      final student = StudentModel.fromMap(map);
      expect(student.id, 's1');
      expect(student.name, 'Charlie');
      expect(student.rollNumber, '42');
      expect(student.className, '10th B');
    });
  });
}

