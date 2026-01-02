import 'dart:convert';
import 'package:http/http.dart' as http;

class RestrictionService {
  final String baseUrl = 'https://teacher-eight-chi.vercel.app'; // Update with your API URL

  /// Check if student is restricted
  Future<Map<String, dynamic>> checkStudentRestrictionStatus(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/restriction-status/$studentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check restriction status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking student restriction status: $e');
      rethrow;
    }
  }
}
