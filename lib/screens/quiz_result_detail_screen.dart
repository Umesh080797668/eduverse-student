import 'package:flutter/material.dart';
import '../models/quiz.dart';

class QuizResultDetailScreen extends StatelessWidget {
  final QuizResult result;

  const QuizResultDetailScreen({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If the populate worked on backend, result.quizId should contain the quiz object
    // But our current model might just store the title strings. 
    // We need to ensure the QuizResult model parses the full quiz details.
    
    // Check if we have question details.
    // Based on the server code: .populate('quizId', 'title description duration questions')
    // The 'questions' array is included.
    
    // However, the QuizResult model used in the Flutter app needs to support this.
    // Let's assume for now we will update the model to hold 'questions' from the populated quizId.
    
    final questions = result.questions ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Result Details'),
      ),
      body: questions.isEmpty
          ? Center(child: Text('Questions details not available.'))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final userAnswerIndex = result.answers.length > index ? result.answers[index] : -1;
                final correctAnswerIndex = question.correctOptionIndex;
                final isCorrect = userAnswerIndex == correctAnswerIndex;

                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${index + 1}. ${question.text}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...List.generate(question.options.length, (optIndex) {
                          final optionText = question.options[optIndex];
                          
                          Color? tileColor;
                          IconData? icon;
                          
                          if (optIndex == correctAnswerIndex) {
                            tileColor = Colors.green.withOpacity(0.2);
                            icon = Icons.check_circle;
                          } else if (optIndex == userAnswerIndex && !isCorrect) {
                            tileColor = Colors.red.withOpacity(0.2);
                            icon = Icons.cancel;
                          }

                          // If the user didn't pick this, and it's not the correct one, standard display
                          
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(8),
                              border: (optIndex == userAnswerIndex || optIndex == correctAnswerIndex)
                                  ? Border.all(
                                      color: optIndex == correctAnswerIndex ? Colors.green : Colors.red,
                                      width: 1
                                    )
                                  : null
                            ),
                            child: ListTile(
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                optionText,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: (optIndex == userAnswerIndex || optIndex == correctAnswerIndex) 
                                      ? FontWeight.bold 
                                      : FontWeight.normal
                                ),
                              ),
                              trailing: icon != null 
                                  ? Icon(
                                      icon, 
                                      color: optIndex == correctAnswerIndex ? Colors.green : Colors.red
                                    ) 
                                  : null,
                            ),
                          );
                        }),
                        if (userAnswerIndex == -1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                "Not Answered",
                                style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey[800] 
                                : Colors.blue[50], 
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey[700]! 
                                    : Colors.blue[100]!
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    "AI Explanation",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                // Placeholder AI explanation logic - in a real app this would come from backend
                                isCorrect 
                                    ? "Great job! You identified the correct answer. This demonstrates a good understanding of the concept." 
                                    : "The correct answer is '${question.options[correctAnswerIndex]}'. Review this topic to understand why other options were incorrect.",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
