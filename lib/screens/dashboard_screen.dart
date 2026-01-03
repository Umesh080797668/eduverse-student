import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'splash_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/admin_changes_provider.dart';
import '../models/attendance.dart';
import '../models/payment.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  final Map<String, Set<int>> _expandedMonths = {}; // className -> set of expanded months

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      
      // Start admin changes polling (covers restrictions and other admin actions)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminChangesProvider = Provider.of<AdminChangesProvider>(context, listen: false);
      if (authProvider.currentUser?.studentId != null) {
        adminChangesProvider.startPolling(
          context: context,
          userId: authProvider.currentUser!.studentId!,
          userType: 'student',
          pollIntervalSeconds: 5,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _stopPolling();
    
    // Stop admin changes polling
    final adminChangesProvider = Provider.of<AdminChangesProvider>(context, listen: false);
    adminChangesProvider.stopPolling();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final adminChangesProvider = Provider.of<AdminChangesProvider>(context, listen: false);

    if (authProvider.currentUser?.studentId != null) {
      if (state == AppLifecycleState.resumed) {
        // App came back to foreground, restart polling
        attendanceProvider.startPolling(authProvider.currentUser!.studentId!, _selectedYear);
        paymentProvider.startPolling(authProvider.currentUser!.studentId!, _selectedYear);
        adminChangesProvider.resumePolling();
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // App went to background, stop polling to save battery
        attendanceProvider.stopPolling();
        paymentProvider.stopPolling();
        adminChangesProvider.pausePolling();
      }
    }
  }

  Future<void> _loadData() async {
    // Clear expanded months when loading new data
    _expandedMonths.clear();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);

    if (authProvider.currentUser?.studentId != null) {
      debugPrint('Dashboard _loadData: studentId=${authProvider.currentUser!.studentId}, year=$_selectedYear');
      // Stop existing polling before loading new data
      attendanceProvider.stopPolling();
      paymentProvider.stopPolling();

      try {
        await Future.wait([
          attendanceProvider.loadAttendance(authProvider.currentUser!.studentId!, year: _selectedYear),
          paymentProvider.loadPayments(authProvider.currentUser!.studentId!, year: _selectedYear),
        ]);

        debugPrint('Dashboard: Data loaded successfully. Attendance: ${attendanceProvider.attendance.length}, Payments: ${paymentProvider.payments.length}');

        // Start polling for real-time updates
        attendanceProvider.startPolling(authProvider.currentUser!.studentId!, _selectedYear);
        paymentProvider.startPolling(authProvider.currentUser!.studentId!, _selectedYear);
      } catch (e) {
        debugPrint('Dashboard: Error loading data: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _stopPolling() {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);

    attendanceProvider.stopPolling();
    paymentProvider.stopPolling();
  }

  void _toggleMonthExpansion(String className, int month) {
    setState(() {
      if (_expandedMonths[className]?.contains(month) ?? false) {
        _expandedMonths[className]?.remove(month);
      } else {
        _expandedMonths.putIfAbsent(className, () => {}).add(month);
      }
    });
  }

  String _getGreetingText() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return 'Hello!';

    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    // Get first part of name
    final nameParts = user.name.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : user.name;

    return '$greeting $firstName';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              _stopPolling();
              await authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Greeting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.blue[50],
            child: Text(
              _getGreetingText(),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Year selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedYear--;
                    });
                    _loadData();
                  },
                ),
                Text(
                  '$_selectedYear',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedYear++;
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Attendance'),
              Tab(text: 'Payments'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Attendance Tab
                _buildAttendanceTab(attendanceProvider),

                // Payments Tab
                _buildPaymentsTab(paymentProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(AttendanceProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final allAttendance = provider.attendance;
    if (allAttendance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No attendance records found for $_selectedYear',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group by class, then by month, then by date
    final groupedByClass = <String, List<Attendance>>{};
    for (var att in allAttendance) {
      // Use the className directly, and fallback only if it's null
      final className = (att.className != null && att.className!.isNotEmpty && att.className != 'Unknown Class')
          ? att.className!
          : 'Class Info Unavailable';
      groupedByClass.putIfAbsent(className, () => []).add(att);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByClass.length,
      itemBuilder: (context, classIndex) {
        final className = groupedByClass.keys.toList()[classIndex];
        final classAttendance = groupedByClass[className]!;

        // Group by month
        final groupedByMonth = <int, List<Attendance>>{};
        for (var att in classAttendance) {
          groupedByMonth.putIfAbsent(att.month, () => []).add(att);
        }

        // Sort months in descending order (most recent first)
        final sortedMonths = groupedByMonth.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                className,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
            // Month sections
            ...sortedMonths.map((month) {
              final monthAttendance = groupedByMonth[month]!;
              final monthName = _getMonthName(month);
              
              // Calculate summary
              final present = monthAttendance.where((a) => a.status.toLowerCase() == 'present').length;
              final absent = monthAttendance.where((a) => a.status.toLowerCase() == 'absent').length;
              final late = monthAttendance.where((a) => a.status.toLowerCase() == 'late').length;
              final total = monthAttendance.length;
              final percentage = total > 0 ? ((present + late) / total * 100).toStringAsFixed(1) : '0.0';

              final isExpanded = _expandedMonths[className]?.contains(month) ?? false;

              return ExpansionTile(
                key: Key('$className-$month'),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  _toggleMonthExpansion(className, month);
                },
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$percentage%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryBadge('Present', present, Colors.green),
                      _buildSummaryBadge('Late', late, Colors.orange),
                      _buildSummaryBadge('Absent', absent, Colors.red),
                    ],
                  ),
                ),
                children: [
                  const SizedBox(height: 8),
                  // Attendance records for this month
                  ...monthAttendance.map((att) => Card(
                    margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(att.status).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(att.status),
                              color: _getStatusColor(att.status),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${att.date.day} ${_getMonthName(att.date.month)} ${att.date.year}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  att.status.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: _getStatusColor(att.status),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 12),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300]
                : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return month > 0 && month <= 12 ? months[month - 1] : 'Unknown';
  }

  Widget _buildPaymentsTab(PaymentProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final allPayments = provider.payments;
    if (allPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No payment records found for $_selectedYear',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group by class
    final groupedByClass = <String, List<Payment>>{};
    for (var payment in allPayments) {
      final className = payment.className ?? 'Class Info Unavailable';
      groupedByClass.putIfAbsent(className, () => []).add(payment);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByClass.length,
      itemBuilder: (context, classIndex) {
        final className = groupedByClass.keys.toList()[classIndex];
        final classPayments = groupedByClass[className]!;

        // Group by month
        final groupedByMonth = <int, List<Payment>>{};
        for (var payment in classPayments) {
          final month = payment.month ?? payment.date.month;
          groupedByMonth.putIfAbsent(month, () => []).add(payment);
        }

        // Sort months in descending order (most recent first)
        final sortedMonths = groupedByMonth.keys.toList()..sort((a, b) => b.compareTo(a));

        final classTotal = classPayments.fold<double>(0, (sum, p) => sum + p.amount);
        
        // Calculate the base class fee (full fee from full payments or the highest payment amount)
        final fullPaymentAmount = classPayments
            .where((p) => p.type.toLowerCase() == 'full')
            .fold<double>(0, (max, p) => p.amount > max ? p.amount : max);
        final baseFeeAmount = fullPaymentAmount > 0 
            ? fullPaymentAmount 
            : classPayments.fold<double>(0, (max, p) => p.amount > max ? p.amount : max);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    className,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Text(
                      '\$${classTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Month sections
            ...sortedMonths.map((month) {
              final monthPayments = groupedByMonth[month]!;
              final monthTotal = monthPayments.fold<double>(0, (sum, p) => sum + p.amount);
              final monthName = _getMonthName(month);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month header
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          monthName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          '\$${monthTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Payment records for this month
                  ...monthPayments.map((payment) {
                    // Calculate amount to pay for partial payments
                    String displayAmount;
                    Color amountColor;
                    
                    if (payment.type.toLowerCase() == 'half' && baseFeeAmount > 0) {
                      // For half payment, show the remaining amount to pay
                      final remainingAmount = baseFeeAmount - payment.amount;
                      displayAmount = '\$${remainingAmount.toStringAsFixed(2)} to pay';
                      amountColor = Colors.orange;
                    } else {
                      // For full or other types, show the amount
                      displayAmount = '\$${payment.amount.toStringAsFixed(2)}';
                      amountColor = Colors.green;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${payment.date.day} ${_getMonthName(payment.date.month)} ${payment.date.year}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    payment.type.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              displayAmount,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: amountColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'excused':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.schedule;
      case 'excused':
        return Icons.info;
      default:
        return Icons.help;
    }
  }
}
