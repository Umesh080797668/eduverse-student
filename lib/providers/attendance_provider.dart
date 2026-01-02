import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<Attendance> _attendance = [];
  bool _isLoading = false;
  final Map<String, List<Attendance>> _attendanceByClass = {};
  Timer? _pollingTimer;
  String? _currentStudentId;
  int? _currentYear;
  String? _errorMessage;

  List<Attendance> get attendance => _attendance;
  bool get isLoading => _isLoading;
  Map<String, List<Attendance>> get attendanceByClass => _attendanceByClass;
  String? get errorMessage => _errorMessage;

  Future<void> loadAttendance(String studentId, {int? month, int? year}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      debugPrint('AttendanceProvider.loadAttendance: Loading for studentId=$studentId, year=$year');
      _attendance = await ApiService.getStudentAttendance(studentId, month: month, year: year);
      _groupAttendanceByClass();
      debugPrint('AttendanceProvider.loadAttendance: Loaded ${_attendance.length} records');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AttendanceProvider.loadAttendance: Error - $e');
      _attendance = [];
      _attendanceByClass.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startPolling(String studentId, int year) {
    stopPolling(); // Stop any existing polling

    _currentStudentId = studentId;
    _currentYear = year;

    // Poll every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentStudentId != null) {
        try {
          final newAttendance = await ApiService.getStudentAttendance(_currentStudentId!, year: _currentYear);
          if (!_areListsEqual(_attendance, newAttendance)) {
            _attendance = newAttendance;
            _groupAttendanceByClass();
            notifyListeners();
          }
        } catch (e) {
          // Silently handle polling errors to avoid disrupting the UI
          debugPrint('Polling error: $e');
        }
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentStudentId = null;
    _currentYear = null;
  }

  bool _areListsEqual(List<Attendance> list1, List<Attendance> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].status != list2[i].status ||
          list1[i].date != list2[i].date) {
        return false;
      }
    }
    return true;
  }

  void _groupAttendanceByClass() {
    _attendanceByClass.clear();
    for (var att in _attendance) {
      final className = att.className ?? 'Unknown Class';
      if (!_attendanceByClass.containsKey(className)) {
        _attendanceByClass[className] = [];
      }
      _attendanceByClass[className]!.add(att);
    }
  }

  List<Attendance> getAttendanceForClass(String className) {
    return _attendanceByClass[className] ?? [];
  }

  Map<String, int> getMonthlyAttendanceStats(String className, int year) {
    final classAttendance = getAttendanceForClass(className);
    Map<String, int> monthlyStats = {};
    
    for (int month = 1; month <= 12; month++) {
      final monthAttendance = classAttendance.where((att) => 
        att.date.month == month && att.date.year == year
      ).toList();
      
      monthlyStats[month.toString()] = monthAttendance.length;
    }
    
    return monthlyStats;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
