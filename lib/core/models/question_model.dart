/// Represents a single question within an exam blueprint.
class QuestionModel {
  final String id;
  final int questionNumber;
  final int marks;
  final String modelAnswer;
  final List<String> keywords;
  final String rubric;

  QuestionModel({
    required this.id,
    required this.questionNumber,
    required this.marks,
    required this.modelAnswer,
    required this.keywords,
    required this.rubric,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionNumber': questionNumber,
      'marks': marks,
      'modelAnswer': modelAnswer,
      'keywords': keywords,
      'rubric': rubric,
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] ?? '',
      questionNumber: map['questionNumber'] ?? 0,
      marks: map['marks'] ?? 0,
      modelAnswer: map['modelAnswer'] ?? '',
      keywords: List<String>.from(map['keywords'] ?? []),
      rubric: map['rubric'] ?? '',
    );
  }

  QuestionModel copyWith({
    String? id,
    int? questionNumber,
    int? marks,
    String? modelAnswer,
    List<String>? keywords,
    String? rubric,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      questionNumber: questionNumber ?? this.questionNumber,
      marks: marks ?? this.marks,
      modelAnswer: modelAnswer ?? this.modelAnswer,
      keywords: keywords ?? this.keywords,
      rubric: rubric ?? this.rubric,
    );
  }
}