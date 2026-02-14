import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';
import 'take_quiz_screen.dart';

class StudentQuizListScreen extends StatefulWidget {
  final String studentId;

  StudentQuizListScreen({required this.studentId});

  @override
  _StudentQuizListScreenState createState() => _StudentQuizListScreenState();
}

class _StudentQuizListScreenState extends State<StudentQuizListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Quiz>> _availableQuizzesFuture;
  late Future<List<QuizResult>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _availableQuizzesFuture = ApiService.getAvailableQuizzes(widget.studentId);
      _historyFuture = ApiService.getQuizHistory(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quizzes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Available'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableList(),
          _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildAvailableList() {
    return FutureBuilder<List<Quiz>>(
      future: _availableQuizzesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final quizzes = snapshot.data ?? [];
        if (quizzes.isEmpty) {
          return Center(child: Text('No quizzes available'));
        }
        return ListView.builder(
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            return ListTile(
              title: Text(quiz.title, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text('${quiz.duration} mins • ${quiz.questions.length} Questions'),
                      SizedBox(height: 4),
                      Text(
                          'Attempts: ${quiz.attemptsTaken}/${quiz.maxAttempts}',
                          style: TextStyle(
                              color: quiz.attemptsTaken >= quiz.maxAttempts ? Colors.red : Colors.green[700],
                              fontSize: 12,
                          ),
                      ),
                  ],
              ),
              isThreeLine: true,
              trailing: quiz.attemptsTaken >= quiz.maxAttempts
                  ? Chip(
                      label: Text('Completed', style: TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: Colors.grey[700],
                    ) 
                  : ElevatedButton(
                      child: Text(quiz.attemptsTaken > 0 ? 'Retake' : 'Start'),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TakeQuizScreen(
                              quiz: quiz,
                              studentId: widget.studentId,
                            ),
                          ),
                        );
                        if (result == true) _refresh();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<QuizResult>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return Center(child: Text('No history'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            String scoreText;
            if (result.percentage != null) {
              scoreText = '${result.percentage!.toStringAsFixed(1)}%';
            } else {
              scoreText = '${result.score}/${result.totalMarks}';
            }
            
            return ListTile(
              title: Text(result.quizTitle),
              subtitle: Text('Date: ${result.submittedAt.toString().substring(0, 10)}'),
              trailing: Text(
                scoreText,
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.lightBlueAccent 
                      : Colors.blue,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
