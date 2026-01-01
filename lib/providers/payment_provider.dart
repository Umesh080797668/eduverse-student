import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/api_service.dart';

class PaymentProvider with ChangeNotifier {
  List<Payment> _payments = [];
  bool _isLoading = false;
  Map<String, List<Payment>> _paymentsByClass = {};
  Timer? _pollingTimer;
  String? _currentStudentId;
  int? _currentYear;
  String? _errorMessage;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;
  Map<String, List<Payment>> get paymentsByClass => _paymentsByClass;
  String? get errorMessage => _errorMessage;

  Future<void> loadPayments(String studentId, {int? month, int? year}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      debugPrint('PaymentProvider.loadPayments: Loading for studentId=$studentId, year=$year');
      _payments = await ApiService.getStudentPayments(studentId, month: month, year: year);
      _groupPaymentsByClass();
      debugPrint('PaymentProvider.loadPayments: Loaded ${_payments.length} records');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('PaymentProvider.loadPayments: Error - $e');
      _payments = [];
      _paymentsByClass.clear();
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
          final newPayments = await ApiService.getStudentPayments(_currentStudentId!, year: _currentYear);
          if (!_areListsEqual(_payments, newPayments)) {
            _payments = newPayments;
            _groupPaymentsByClass();
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

  bool _areListsEqual(List<Payment> list1, List<Payment> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].amount != list2[i].amount ||
          list1[i].date != list2[i].date) {
        return false;
      }
    }
    return true;
  }

  void _groupPaymentsByClass() {
    _paymentsByClass.clear();
    for (var payment in _payments) {
      final className = payment.className ?? 'Unknown Class';
      if (!_paymentsByClass.containsKey(className)) {
        _paymentsByClass[className] = [];
      }
      _paymentsByClass[className]!.add(payment);
    }
  }

  List<Payment> getPaymentsForClass(String className) {
    return _paymentsByClass[className] ?? [];
  }

  Map<String, double> getMonthlyPaymentStats(String className, int year) {
    final classPayments = getPaymentsForClass(className);
    Map<String, double> monthlyStats = {};
    
    for (int month = 1; month <= 12; month++) {
      final monthPayments = classPayments.where((payment) => 
        payment.date.month == month && payment.date.year == year
      ).toList();
      
      final total = monthPayments.fold(0.0, (sum, payment) => sum + payment.amount);
      monthlyStats[month.toString()] = total;
    }
    
    return monthlyStats;
  }

  double getTotalPaymentsForClass(String className) {
    final classPayments = getPaymentsForClass(className);
    return classPayments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
