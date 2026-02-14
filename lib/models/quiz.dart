class QuizQuestion {
  String text;
  List<String> options;
  int? correctOptionIndex; // Only for history/results, hidden during quiz
  int marks;

  QuizQuestion({
    required this.text,
    required this.options,
    this.correctOptionIndex,
    this.marks = 1,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      text: json['text'],
      options: List<String>.from(json['options']),
      correctOptionIndex: json['correctOptionIndex'], // Might be null for student view
      marks: json['marks'] ?? 1,
    );
  }
}

class Quiz {
  String? id;
  String title;
  String? description;
  List<QuizQuestion> questions;
  int duration; // minutes
  int maxAttempts;
  bool isTaken; // Kept for backward compatibility or simple check
  int attemptsTaken; // New field from backend to track usage

  Quiz({
    this.id,
    required this.title,
    this.description,
    required this.questions,
    required this.duration,
    this.maxAttempts = 1,
    this.isTaken = false,
    this.attemptsTaken = 0,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['_id'],
      title: json['title'],
      description: json['description'],
      questions: (json['questions'] as List)
          .map((q) => QuizQuestion.fromJson(q))
          .toList(),
      duration: json['duration'],
      maxAttempts: json['maxAttempts'] ?? 1,
      isTaken: json['isTaken'] ?? false,
      attemptsTaken: json['attemptsTaken'] ?? 0,
    );
  }
}

class QuizResult {
  String id;
  String quizId;
  String quizTitle;
  int score;
  int totalMarks;
  double? percentage;
  DateTime submittedAt;

  QuizResult({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.score,
    required this.totalMarks,
    this.percentage,
    required this.submittedAt,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      id: json['_id'],
      quizId: json['quizId'] is String ? json['quizId'] : (json['quizId']['_id'] ?? ''),
      quizTitle: json['quizId'] is Map ? (json['quizId']['title'] ?? 'Unknown Quiz') : 'Unknown Quiz',
      score: json['score'],
      totalMarks: json['totalMarks'],
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      submittedAt: DateTime.parse(json['submittedAt']),
    );
  }
}
