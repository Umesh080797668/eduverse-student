import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // Use dotenv to retrieve the API key
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? ''; 
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  static Future<String> getExplanation({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String userAnswer,
    required bool isCorrect,
  }) async {
    try {
      final prompt = '''
You are an AI tutor. Provide a concise explanation (3-7 lines) for the following quiz question.
Explain why the correct answer is right and, if the user was wrong, why their answer was incorrect.
Keep the tone encouraging and educational.

Question: $question
Options: ${options.join(', ')}
Correct Answer: $correctAnswer
User Answer: $userAnswer
Result: ${isCorrect ? 'Correct' : 'Incorrect'}
''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        }
      }
      
      return "Unable to generate explanation at this time.";
    } catch (e) {
      print('Gemini API Error: $e');
      return "Explanation currently unavailable.";
    }
  }
}
