class Payment {
  final String id;
  final String studentId;
  final String classId;
  final String? className;
  final double amount;
  final String type; // 'full', 'half', 'free'
  final DateTime date;
  final int? month;

  Payment({
    required this.id,
    required this.studentId,
    required this.classId,
    this.className,
    required this.amount,
    required this.type,
    required this.date,
    this.month,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date']);
    final month = json['month'] ?? date.month; // Derive from date if not provided
    
    // Handle classId being either a string or an object
    String? extractedClassId;
    if (json['classId'] is String) {
      extractedClassId = json['classId'];
    } else if (json['classId'] is Map) {
      extractedClassId = json['classId']['_id'] ?? json['classId']['id'];
    }
    
    // Handle className being extracted from classId object if needed
    String? extractedClassName = json['className'];
    if (extractedClassName == null && json['classId'] is Map) {
      extractedClassName = json['classId']['name'];
    }
    
    return Payment(
      id: json['_id'] ?? json['id'],
      studentId: json['studentId'] is String ? json['studentId'] : (json['studentId'] is Map ? json['studentId']['_id'] : 'Unknown'),
      classId: extractedClassId ?? 'Unknown',
      className: extractedClassName,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      date: date,
      month: month,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'classId': classId,
      'className': className,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'month': month,
    };
  }
}