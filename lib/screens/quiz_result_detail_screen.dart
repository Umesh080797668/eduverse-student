import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => _showLeaderboard(context, result.quizId),
          ),
        ],
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
                          
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final greenColor = isDark ? Colors.lightGreenAccent : Colors.green;
                          final redColor = isDark ? Colors.redAccent : Colors.red;

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(8),
                              border: (optIndex == userAnswerIndex || optIndex == correctAnswerIndex)
                                  ? Border.all(
                                      color: optIndex == correctAnswerIndex ? greenColor : redColor,
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
                                      color: optIndex == correctAnswerIndex ? greenColor : redColor
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
                        AiExplanationBox(
                          question: question.text,
                          options: question.options,
                          correctAnswer: question.options[correctAnswerIndex ?? 0],
                          userAnswer: userAnswerIndex != -1 ? question.options[userAnswerIndex] : "No Answer",
                          isCorrect: isCorrect,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showLeaderboard(BuildContext context, String quizId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Top Performers'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.getLeaderboard(quizId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            final data = snapshot.data ?? [];
            if (data.isEmpty) return const Text('No active leaderboard data.');
            
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  // If real names are used as requested
                  final name = item['name'] ?? 'Student';
                  final score = item['score'] ?? 0;
                  final total = item['totalMarks'] ?? 0;
                  final percentage = total > 0 ? (score / total * 100).toStringAsFixed(1) : "0.0";
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey[400] : (index == 2 ? Colors.brown[300] : Colors.blueGrey[100])),
                      child: Text('${index + 1}'),
                    ),
                    title: Text(name),
                    trailing: Text('$score/$total ($percentage%)'),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class AiExplanationBox extends StatefulWidget {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String userAnswer;
  final bool isCorrect;

  const AiExplanationBox({
    Key? key,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.userAnswer,
    required this.isCorrect,
  }) : super(key: key);

  @override
  _AiExplanationBoxState createState() => _AiExplanationBoxState();
}

class _AiExplanationBoxState extends State<AiExplanationBox> {
  String? _explanation;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final text = await GeminiService.getExplanation(
        question: widget.question,
        options: widget.options,
        correctAnswer: widget.correctAnswer,
        userAnswer: widget.userAnswer,
        isCorrect: widget.isCorrect,
      );
      if (mounted) {
        setState(() {
          _explanation = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Spacer(),
               if (_hasError)
                IconButton(
                  icon: Icon(Icons.refresh, size: 16, color: Colors.red),
                  onPressed: _fetchExplanation,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                )
            ],
          ),
          SizedBox(height: 6),
          _isLoading
              ? ShimmerLoading()
              : Text(
                  _explanation ?? "Generating explanation...",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
        ],
      ),
    );
  }
}

class ShimmerLoading extends StatefulWidget {
  @override
  _ShimmerLoadingState createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + 0.5 * _controller.value, // Simple blink effect
          child: Container(
            height: 12,
            width: double.infinity,
            color: Colors.grey.withOpacity(0.3),
            margin: EdgeInsets.only(bottom: 4),
          ),
        );
      },
    );
  }
}
