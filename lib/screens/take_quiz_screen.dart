import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz.dart';
import '../services/api_service.dart';

class TakeQuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String studentId;

  TakeQuizScreen({required this.quiz, required this.studentId});

  @override
  _TakeQuizScreenState createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  late List<int> _answers;
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _submitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.quiz.questions.length, -1);
    // Initialize timer tentatively; will be overwritten by _loadState if exists
    _secondsRemaining = widget.quiz.duration * 60;
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quiz_progress_${widget.studentId}_${widget.quiz.id}';
    final savedData = prefs.getString(key);

    try {
      if (savedData != null) {
        final data = json.decode(savedData);
        final List<dynamic> savedAnswers = data['answers'];
        final int? targetEndTimeMillis = data['targetEndTime'];
        
        if (savedAnswers.length == widget.quiz.questions.length && targetEndTimeMillis != null) {
          final DateTime targetEndTime = DateTime.fromMillisecondsSinceEpoch(targetEndTimeMillis);
          final now = DateTime.now();
          final remaining = targetEndTime.difference(now).inSeconds;

          if (remaining > 0) {
              setState(() {
                _answers = savedAnswers.cast<int>();
                _secondsRemaining = remaining;
              });
              setState(() => _isLoading = false);
              _startTimer();
              return;
          } else {
             // Time technically expired while closed. Attempt auto-submit or just let it start with 0 and auto-submit immediately?
             // Better to let it flow to _startTimer -> immediate submit
             setState(() {
                _answers = savedAnswers.cast<int>();
                _secondsRemaining = 0;
             });
              setState(() => _isLoading = false);
              _startTimer(); // Will trigger immediate submit
              return;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading quiz state: $e");
      await _clearState();
    }
    
    // First time starting or corrupted state
    final targetEndTime = DateTime.now().add(Duration(minutes: widget.quiz.duration));
    // Initial save
    await _saveState(targetEndTime: targetEndTime);
    
    setState(() => _isLoading = false);
    _startTimer();
  }

  Future<void> _saveState({DateTime? targetEndTime}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quiz_progress_${widget.studentId}_${widget.quiz.id}';
    
    // If targetEndTime is not provided, try to retrieve existing one or calculate new (should exist usually)
    int endTimeMillis;
    if (targetEndTime != null) {
      endTimeMillis = targetEndTime.millisecondsSinceEpoch;
    } else {
      // Read existing to keep same end time
      final existing = prefs.getString(key);
      if (existing != null) {
        endTimeMillis = json.decode(existing)['targetEndTime'];
      } else {
        // Fallback (should rarely happen if flow is correct)
        endTimeMillis = DateTime.now().add(Duration(seconds: _secondsRemaining)).millisecondsSinceEpoch;
      }
    }

    final data = {
      'answers': _answers,
      'targetEndTime': endTimeMillis,
    };
    
    await prefs.setString(key, json.encode(data));
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quiz_progress_${widget.studentId}_${widget.quiz.id}';
    await prefs.remove(key);
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submitQuiz() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final result = await ApiService.submitQuiz(
        widget.studentId,
        widget.quiz.id!,
        _answers,
      );

      await _clearState();

      if (!mounted) return;

      // Show result dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Quiz Completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your Score:', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text(
                '${result.score} / ${result.totalMarks}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              if (result.percentage != null) ...[
                 SizedBox(height: 5),
                 Text(
                    '${result.percentage!.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                 ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Close screen and return true
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return "00:00";
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                _formatTime(_secondsRemaining),
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining < 60 ? Colors.red : null, // Warn if < 1 min
                ),
              ),
            ),
          ),
        ],
      ),
      body: _submitting
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: widget.quiz.questions.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.quiz.questions.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: ElevatedButton(
                      onPressed: _submitQuiz,
                      child: Text('Submit Quiz'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  );
                }

                final question = widget.quiz.questions[index];
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 10),
                        ...question.options.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String option = entry.value;
                          return RadioListTile<int>(
                            title: Text(option),
                            value: idx,
                            groupValue: _answers[index],
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) {
                              setState(() => _answers[index] = val!);
                              _saveState();
                            },
                            contentPadding: EdgeInsets.zero,
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
