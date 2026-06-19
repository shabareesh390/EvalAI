class QuestionResult {
  final int questionNumber;
  final int marksAwarded;
  final int totalMarks;
  final String strengths;
  final String weaknesses;
  final String missingConcepts;
  final String suggestions;
  final double aiConfidence;

  QuestionResult({
    required this.questionNumber,
    required this.marksAwarded,
    required this.totalMarks,
    required this.strengths,
    required this.weaknesses,
    required this.missingConcepts,
    required this.suggestions,
    required this.aiConfidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionNumber': questionNumber,
      'marksAwarded': marksAwarded,
      'totalMarks': totalMarks,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'missingConcepts': missingConcepts,
      'suggestions': suggestions,
      'aiConfidence': aiConfidence,
    };
  }

  factory QuestionResult.fromMap(Map<String, dynamic> map) {
    return QuestionResult(
      questionNumber: map['questionNumber'] ?? 0,
      marksAwarded: map['marksAwarded'] ?? 0,
      totalMarks: map['totalMarks'] ?? 0,
      strengths: map['strengths'] ?? '',
      weaknesses: map['weaknesses'] ?? '',
      missingConcepts: map['missingConcepts'] ?? '',
      suggestions: map['suggestions'] ?? '',
      aiConfidence: (map['aiConfidence'] ?? 0).toDouble(),
    );
  }
}

class EvaluationModel {
  final String id;
  final String examId;
  final String examName;
  final String studentId;
  final String studentName;
  final String studentUsn;
  final String studentRollNumber;
  final String teacherId;
  final int totalMarksAwarded;
  final int totalMarks;
  final String overallFeedback;
  final List<QuestionResult> questionResults;
  final String extractedText;
  final double ocrConfidence;
  final DateTime evaluatedAt;

  EvaluationModel({
    required this.id,
    required this.examId,
    required this.examName,
    required this.studentId,
    required this.studentName,
    required this.studentUsn,
    required this.studentRollNumber,
    required this.teacherId,
    required this.totalMarksAwarded,
    required this.totalMarks,
    required this.overallFeedback,
    required this.questionResults,
    required this.extractedText,
    required this.ocrConfidence,
    required this.evaluatedAt,
  });

  double get percentage =>
      totalMarks > 0 ? (totalMarksAwarded / totalMarks) * 100 : 0;

  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  bool get isPassed => percentage >= 50;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'examName': examName,
      'studentId': studentId,
      'studentName': studentName,
      'studentUsn': studentUsn,
      'studentRollNumber': studentRollNumber,
      'teacherId': teacherId,
      'totalMarksAwarded': totalMarksAwarded,
      'totalMarks': totalMarks,
      'overallFeedback': overallFeedback,
      'questionResults': questionResults.map((q) => q.toMap()).toList(),
      'extractedText': extractedText,
      'ocrConfidence': ocrConfidence,
      'evaluatedAt': evaluatedAt.toIso8601String(),
    };
  }

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'] ?? '',
      examId: map['examId'] ?? '',
      examName: map['examName'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentUsn: map['studentUsn'] ?? '',
      studentRollNumber: map['studentRollNumber'] ?? '',
      teacherId: map['teacherId'] ?? '',
      totalMarksAwarded: map['totalMarksAwarded'] ?? 0,
      totalMarks: map['totalMarks'] ?? 0,
      overallFeedback: map['overallFeedback'] ?? '',
      questionResults: (map['questionResults'] as List<dynamic>?)
          ?.map((q) => QuestionResult.fromMap(q as Map<String, dynamic>))
          .toList() ??
          [],
      extractedText: map['extractedText'] ?? '',
      ocrConfidence: (map['ocrConfidence'] ?? 0).toDouble(),
      evaluatedAt: DateTime.parse(
          map['evaluatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}