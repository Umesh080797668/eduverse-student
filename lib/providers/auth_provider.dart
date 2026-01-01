import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';

class UserAccount {
  final String email;
  final String name;
  final String? studentId;
  final String? studentNumber;
  final Map<String, dynamic>? studentData;
  final DateTime lastLogin;

  UserAccount({
    required this.email,
    required this.name,
    this.studentId,
    this.studentNumber,
    this.studentData,
    DateTime? lastLogin,
  }) : lastLogin = lastLogin ?? DateTime.now();

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      email: json['email'],
      name: json['name'],
      studentId: json['studentId'],
      studentNumber: json['studentNumber'],
      studentData: json['studentData'],
      lastLogin: DateTime.parse(json['lastLogin']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'studentId': studentId,
      'studentNumber': studentNumber,
      'studentData': studentData,
      'lastLogin': lastLogin.toIso8601String(),
    };
  }

  UserAccount copyWith({
    String? email,
    String? name,
    String? studentId,
    String? studentNumber,
    Map<String, dynamic>? studentData,
    DateTime? lastLogin,
  }) {
    return UserAccount(
      email: email ?? this.email,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      studentNumber: studentNumber ?? this.studentNumber,
      studentData: studentData ?? this.studentData,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  UserAccount? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _isLoggedIn = false;

  UserAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (userData != null && isLoggedIn) {
      try {
        final userJson = json.decode(userData);
        _currentUser = UserAccount.fromJson(userJson);
        _isAuthenticated = true;
        _isLoggedIn = true;
      } catch (e) {
        debugPrint('Error loading user data: $e');
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> login(String studentNumber, String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.loginStudent(studentNumber, email);
      debugPrint('Login response: $response');
      
      if (response['success'] == true && response['student'] != null) {
        final userData = response['student'];
        debugPrint('User data keys: ${userData.keys.toList()}');
        debugPrint('User data: $userData');
        
        // Use the MongoDB 'id' field as studentId for API queries
        // Use the 'studentId' field as studentNumber for display
        _currentUser = UserAccount(
          email: userData['email'] ?? '',
          name: userData['name'] ?? 'Unknown',
          studentId: userData['id'] ?? userData['_id'],  // MongoDB ID for API queries
          studentNumber: userData['studentId'] ?? studentNumber,  // Student number for display
          studentData: userData,
        );
        
        debugPrint('UserAccount created: email=${_currentUser!.email}, name=${_currentUser!.name}, studentId=${_currentUser!.studentId}, studentNumber=${_currentUser!.studentNumber}');
        
        _isAuthenticated = true;
        _isLoggedIn = true;
        
        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', json.encode(_currentUser!.toJson()));
        await prefs.setBool('is_logged_in', true);
        
        _errorMessage = null;
      } else {
        // Check if there's an error message in the response
        _errorMessage = response['message'] ?? response['error'] ?? 'Login failed. Please verify your credentials.';
        _isAuthenticated = false;
        _isLoggedIn = false;
      }
    } catch (e) {
      // Parse the error message from the exception
      _errorMessage = e.toString();
      if (_errorMessage!.startsWith('ApiException: ')) {
        _errorMessage = _errorMessage!.replaceFirst('ApiException: ', '');
      }
      debugPrint('Login error: $e');
      _isAuthenticated = false;
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    _isLoggedIn = false;
    _errorMessage = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.setBool('is_logged_in', false);
    
    notifyListeners();
  }

  Future<void> updateUser(UserAccount updatedUser) async {
    _currentUser = updatedUser;
    
    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(_currentUser!.toJson()));
    
    notifyListeners();
  }

  Future<void> checkStatusNow() async {
    if (!_isLoggedIn || _currentUser == null) return;
    
    try {
      // Check if student is still active
      final response = await ApiService.checkStudentStatus(_currentUser!.studentId!);
      if (response['success'] != true) {
        await logout();
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
