class Attendance {
  final String id;
  final String studentId;
  final String? classId;
  final String? className;
  final DateTime date;
  final String session;
  final String status;
  final int month;
  final int year;
  final DateTime? createdAt;

  Attendance({
    required this.id,
    required this.studentId,
    this.classId,
    this.className,
    required this.date,
    required this.session,
    required this.status,
    required this.month,
    required this.year,
    this.createdAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    // Handle studentId being either a string or an object
    String? extractedStudentId;
    if (json['studentId'] is String) {
      extractedStudentId = json['studentId'];
    } else if (json['studentId'] is Map) {
      extractedStudentId =
          json['studentId']['_id'] ?? json['studentId']['studentId'];
    }

    // Extract className from various possible locations
    String? extractedClassName = json['className'];

    // Try to extract from classId object
    if ((extractedClassName == null || extractedClassName.isEmpty) &&
        json['classId'] is Map) {
      extractedClassName = json['classId']['name'] ??
          json['classId']['className'] ??
          json['classId']['class'] ??
          json['classId']['_name'];
    }

    // Additional fallback for nested class info
    if ((extractedClassName == null || extractedClassName.isEmpty) &&
        json['classId'] is Map) {
      if (json['classId']['classData'] is Map) {
        extractedClassName = json['classId']['classData']['name'] ??
            json['classId']['classData']['className'];
      }
    }

    // Extract classId
    String? extractedClassId;
    if (json['classId'] is String) {
      extractedClassId = json['classId'];
    } else if (json['classId'] is Map) {
      extractedClassId = json['classId']['_id'] ?? json['classId']['id'];
    }

    return Attendance(
      id: json['_id'] ?? json['id'],
      studentId: extractedStudentId ?? 'Unknown',
      classId: extractedClassId,
      className: extractedClassName ?? 'Class Info Unavailable',
      date: DateTime.parse(json['date']),
      session: json['session'],
      status: json['status'],
      month: json['month'],
      year: json['year'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'classId': classId,
      'className': className,
      'date': date.toIso8601String(),
      'session': session,
      'status': status,
      'month': month,
      'year': year,
    };
  }
}
