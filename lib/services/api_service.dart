import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/payment.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ApiService {
  // For production (hosted backend), use multiple URLs for load balancing
  static const List<String> baseUrls = [
    'https://teacher-eight-chi.vercel.app',
    // Add more URLs if available for load balancing
  ];
  static int _currentUrlIndex = 0;

  // Helper method to extract error message from response body
  static String? _extractErrorMessage(String responseBody) {
    try {
      final data = json.decode(responseBody);
      return data['error'] ?? data['message'] ?? data['msg'];
    } catch (e) {
      return null;
    }
  }

  static String get baseUrl {
    // Round-robin load balancing
    _currentUrlIndex = (_currentUrlIndex + 1) % baseUrls.length;
    return baseUrls[_currentUrlIndex];
  }

  // Timeout duration for all requests
  static const Duration timeout = Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Centralized HTTP request method with error handling
  static Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? queryParams,
  }) async {
    final uri = Uri.parse('${baseUrl}$endpoint').replace(queryParameters: queryParams);

    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        http.Response response;

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: requestHeaders).timeout(timeout);
            break;
          case 'POST':
            response = await http.post(uri, headers: requestHeaders, body: json.encode(body)).timeout(timeout);
            break;
          case 'PUT':
            response = await http.put(uri, headers: requestHeaders, body: json.encode(body)).timeout(timeout);
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: requestHeaders).timeout(timeout);
            break;
          default:
            throw ApiException('Unsupported HTTP method: $method');
        }

        // Check for successful response
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // Handle specific error codes
        if (response.statusCode == 401) {
          final errorMsg = _extractErrorMessage(response.body) ?? 'Invalid credentials. Please check your student number and email.';
          throw ApiException(errorMsg, statusCode: 401);
        } else if (response.statusCode == 403) {
          final errorMsg = _extractErrorMessage(response.body) ?? 'Access forbidden';
          throw ApiException(errorMsg, statusCode: 403);
        } else if (response.statusCode == 404) {
          final errorMsg = _extractErrorMessage(response.body) ?? 'Student not found. Please verify your credentials.';
          throw ApiException(errorMsg, statusCode: 404);
        } else if (response.statusCode >= 500) {
          // Retry on server errors
          if (attempt < maxRetries) {
            await Future.delayed(retryDelay * attempt);
            continue;
          }
          throw ApiException('Server error: ${response.statusCode}', statusCode: response.statusCode);
        } else {
          // For other client errors, don't retry
          throw ApiException('Request failed: ${response.statusCode}', statusCode: response.statusCode);
        }
      } on SocketException {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        throw ApiException('Network connection failed. Please check your internet connection.');
      } on TimeoutException {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        throw ApiException('Request timed out. Please try again.');
      } catch (e) {
        if (attempt == maxRetries) {
          if (e is ApiException) rethrow;
          throw ApiException('Unexpected error: ${e.toString()}');
        }
      }
    }

    throw ApiException('Request failed after $maxRetries attempts');
  }

  // Student login with student number and email
  static Future<Map<String, dynamic>> loginStudent(String studentNumber, String email) async {
    try {
      final response = await _makeRequest('POST', '/api/student/login', body: {
        'studentNumber': studentNumber,
        'email': email,
      });

      final data = json.decode(response.body);
      if (data['success'] != true && data['error'] == null && data['message'] == null) {
        // If success is false but no error message, provide a helpful one
        throw ApiException('Login failed. Please verify your student number and email are correct.');
      }
      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Login failed: ${e.toString()}');
    }
  }

  // Get student attendance
  static Future<List<Attendance>> getStudentAttendance(String studentId, {int? month, int? year}) async {
    try {
      final queryParams = <String, dynamic>{'studentId': studentId};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      debugPrint('getStudentAttendance: studentId=$studentId, queryParams=$queryParams');

      final response = await _makeRequest('GET', '/api/student/attendance', queryParams: queryParams);

      debugPrint('getStudentAttendance: response status=${response.statusCode}, body=${response.body}');

      final data = json.decode(response.body);
      if (data['success'] == true && data['attendance'] != null) {
        final attendanceList = (data['attendance'] as List).isNotEmpty ? (data['attendance'] as List) : [];
        return attendanceList.map((item) => Attendance.fromJson(item)).toList();
      } else if (data['attendance'] == null) {
        // No attendance records found - return empty list
        debugPrint('getStudentAttendance: No attendance records found');
        return [];
      } else {
        final errorMsg = data['error'] ?? data['message'] ?? 'Failed to load attendance';
        throw ApiException(errorMsg);
      }
    } catch (e) {
      debugPrint('getStudentAttendance: error=$e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to load attendance: ${e.toString()}');
    }
  }

  // Get student payments
  static Future<List<Payment>> getStudentPayments(String studentId, {int? month, int? year}) async {
    try {
      final queryParams = <String, dynamic>{'studentId': studentId};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      debugPrint('getStudentPayments: studentId=$studentId, queryParams=$queryParams');

      final response = await _makeRequest('GET', '/api/student/payments', queryParams: queryParams);

      debugPrint('getStudentPayments: response status=${response.statusCode}, body=${response.body}');

      final data = json.decode(response.body);
      if (data['success'] == true && data['payments'] != null) {
        final paymentsList = (data['payments'] as List).isNotEmpty ? (data['payments'] as List) : [];
        return paymentsList.map((item) => Payment.fromJson(item)).toList();
      } else if (data['payments'] == null) {
        // No payment records found - return empty list
        debugPrint('getStudentPayments: No payment records found');
        return [];
      } else {
        final errorMsg = data['error'] ?? data['message'] ?? 'Failed to load payments';
        throw ApiException(errorMsg);
      }
    } catch (e) {
      debugPrint('getStudentPayments: error=$e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to load payments: ${e.toString()}');
    }
  }

  // Check student status
  static Future<Map<String, dynamic>> checkStudentStatus(String studentId) async {
    try {
      final response = await _makeRequest('GET', '/api/student/status', queryParams: {'studentId': studentId});

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      throw ApiException('Failed to check status: ${e.toString()}');
    }
  }

  // Submit problem report
  static Future<Map<String, dynamic>> submitProblemReport({
    required String userEmail,
    required String issueDescription,
    String? appVersion,
    String? device,
    String? studentId,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/api/reports/problem',
        body: {
          'userEmail': userEmail,
          'issueDescription': issueDescription,
          'appVersion': appVersion,
          'device': device,
          'studentId': studentId,
        },
      );

      if (response.statusCode != 201) {
        throw ApiException('Failed to submit problem report', statusCode: response.statusCode);
      }

      return json.decode(response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to submit problem report: ${e.toString()}');
    }
  }

  // Update student profile
  static Future<Map<String, dynamic>> updateStudent(String studentId, Map<String, dynamic> updateData) async {
    try {
      final response = await _makeRequest(
        'PUT',
        '/api/students/$studentId',
        body: updateData,
      );

      if (response.statusCode != 200) {
        throw ApiException('Failed to update student profile', statusCode: response.statusCode);
      }

      return json.decode(response.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update profile: ${e.toString()}');
    }
  }
}
