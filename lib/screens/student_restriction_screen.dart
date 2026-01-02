import 'package:flutter/material.dart';
import 'dart:async';
import '../services/restriction_service.dart';

class StudentRestrictionScreen extends StatefulWidget {
  final String studentId;
  final String? initialReason;

  const StudentRestrictionScreen({
    Key? key,
    required this.studentId,
    this.initialReason,
  }) : super(key: key);

  @override
  State<StudentRestrictionScreen> createState() => _StudentRestrictionScreenState();
}

class _StudentRestrictionScreenState extends State<StudentRestrictionScreen> with WidgetsBindingObserver {
  final RestrictionService _restrictionService = RestrictionService();
  Timer? _pollTimer;
  String? _restrictionReason;
  DateTime? _restrictedAt;
  bool _isLoading = true;
  List<dynamic> _availableClasses = [];
  List<dynamic> _restrictedClasses = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restrictionReason = widget.initialReason;
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _checkRestrictionStatus();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkRestrictionStatus();
    });
  }

  Future<void> _checkRestrictionStatus() async {
    try {
      final status = await _restrictionService.checkStudentRestrictionStatus(widget.studentId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // If no longer restricted, navigate back to main app
        if (!status['isRestricted']) {
          _pollTimer?.cancel();
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          setState(() {
            _restrictionReason = status['restrictionReason'];
            _restrictedAt = status['restrictedAt'] != null 
                ? DateTime.parse(status['restrictedAt']) 
                : null;
            _availableClasses = status['availableClasses'] ?? [];
            _restrictedClasses = status['restrictedClasses'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error checking restriction status: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Restriction Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block,
                      size: 60,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Account Restricted',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Message
                  Text(
                    'Your account has been temporarily restricted.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Reason Card
                  if (_restrictionReason != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, 
                                color: Colors.red.shade700, 
                                size: 20
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reason:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _restrictionReason!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (_restrictedAt != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Restricted on: ${_formatDateTime(_restrictedAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Available Classes (if any)
                  if (_availableClasses.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Available Classes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...(_availableClasses.map((cls) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.class_,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${cls['name']} - ${cls['teacherName']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))).toList(),
                          const SizedBox(height: 8),
                          Text(
                            'You can still access these classes once the restriction is lifted.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Restricted Classes
                  if (_restrictedClasses.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Restricted Classes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...(_restrictedClasses.map((cls) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.class_,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${cls['name']} - ${cls['teacherName']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Contact Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.contact_support,
                          color: Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please contact your teacher or administrator for more information.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Loading indicator
                  if (_isLoading)
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Checking status...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
