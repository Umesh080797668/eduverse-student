import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/admin_changes_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AdminChangesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Eduverse Student Panel',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme.copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryColor: Colors.teal, // Different color for student app
            colorScheme: themeProvider.lightTheme.colorScheme.copyWith(
              primary: Colors.teal,
              secondary: Colors.tealAccent,
            ),
          ),
          darkTheme: themeProvider.darkTheme.copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryColor: Colors.teal,
            colorScheme: themeProvider.darkTheme.colorScheme.copyWith(
              primary: Colors.teal,
              secondary: Colors.tealAccent,
            ),
          ),
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const AppLifecycleWrapper(),
        );
      },
    );
  }
}

class AppLifecycleWrapper extends StatefulWidget {
  const AppLifecycleWrapper({super.key});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check user status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkUserStatusOnResume();
    }
  }

  Future<void> _checkUserStatusOnResume() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Only check if user is logged in
    if (authProvider.isAuthenticated && authProvider.isLoggedIn) {
      try {
        await authProvider.checkStatusNow();
      } catch (e) {
        debugPrint('Error checking user status on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
