/// Represents a student enrolled in a class section.
class StudentModel {
  final String id;
  final String name;
  final String usn;
  final String rollNumber;
  final String className;
  final String section;
  final String teacherId;

  StudentModel({
    required this.id,
    required this.name,
    required this.usn,
    required this.rollNumber,
    required this.className,
    required this.section,
    required this.teacherId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'usn': usn,
      'rollNumber': rollNumber,
      'className': className,
      'section': section,
      'teacherId': teacherId,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      usn: map['usn'] ?? '',
      rollNumber: (map['rollNumber'] ?? map['roll_number'] ?? map['rollNo'] ?? '').toString(),
      className: (map['className'] ?? map['class_name'] ?? map['class'] ?? '').toString(),
      section: (map['section'] ?? '').toString(),
      teacherId: map['teacherId'] ?? map['teacher_id'] ?? '',
    );
  }
}