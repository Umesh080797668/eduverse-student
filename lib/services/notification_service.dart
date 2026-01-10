import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

/// Enhanced Notification Channels
final AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
  'critical_channel',
  'Critical Notifications',
  description: 'Important alerts requiring immediate attention',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('critical_alert'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
  ledColor: Colors.red,
  enableLights: true,
);

final AndroidNotificationChannel successChannel = AndroidNotificationChannel(
  'success_channel',
  'Success Notifications',
  description: 'Positive updates and confirmations',
  importance: Importance.high,
  sound: RawResourceAndroidNotificationSound('success_chime'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
  ledColor: Colors.green,
  enableLights: true,
);

final AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
  'general_channel',
  'General Notifications',
  description: 'General app notifications and updates',
  importance: Importance.defaultImportance,
  sound: RawResourceAndroidNotificationSound('notification_default'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
  ledColor: Colors.blue,
  enableLights: true,
);

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title}');
  
  // Display local notification for background message
  final notification = message.notification;
  if (notification != null) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Use smart notification details for background messages
    final data = message.data;
    final type = data['type'] as String? ?? 'general';
    final androidDetails = _getNotificationDetailsForType(type);
    
    final notificationDetails = NotificationDetails(android: androidDetails);
    
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title ?? 'Notification',
      notification.body ?? '',
      notificationDetails,
      payload: json.encode(message.data),
    );
  }
}

/// Get notification details for background handler
AndroidNotificationDetails _getNotificationDetailsForType(String type) {
  switch (type) {
    case 'subscription_approved':
    case 'subscription_activated':
    case 'free_subscription_granted':
      return AndroidNotificationDetails(
        successChannel.id,
        successChannel.name,
        channelDescription: successChannel.description,
        importance: successChannel.importance,
        color: Colors.green,
        colorized: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );

    case 'restriction':
    case 'student_restricted':
      return AndroidNotificationDetails(
        criticalChannel.id,
        criticalChannel.name,
        channelDescription: criticalChannel.description,
        importance: criticalChannel.importance,
        color: Colors.red,
        colorized: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
        actions: [
          const AndroidNotificationAction('view_details', 'View Details'),
          const AndroidNotificationAction('dismiss', 'Dismiss'),
        ],
      );

    default:
      return AndroidNotificationDetails(
        generalChannel.id,
        generalChannel.name,
        channelDescription: generalChannel.description,
        importance: generalChannel.importance,
        color: Colors.blue,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Cloud Messaging and Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load notification preferences
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
      );

      // Create notification channels
      await _createNotificationChannels();

      // Request notification permissions
      if (_notificationsEnabled) {
        await _requestPermissions();
      }

      // Set up Firebase Cloud Messaging
      await _setupFirebaseMessaging();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(criticalChannel);
      await androidPlugin.createNotificationChannel(successChannel);
      await androidPlugin.createNotificationChannel(generalChannel);
      debugPrint('Notification channels created successfully');
    }
  }

  /// Handle background notification actions
  @pragma('vm:entry-point')
  static void _onBackgroundAction(NotificationResponse response) async {
    debugPrint('Background action received: ${response.actionId}');
    
    switch (response.actionId) {
      case 'view_details':
        // Handle view details action
        debugPrint('View details action triggered');
        break;
      case 'dismiss':
        // Handle dismiss action
        debugPrint('Dismiss action triggered');
        break;
      default:
        debugPrint('Unknown action: ${response.actionId}');
    }
  }

  /// Get notification details based on type
  AndroidNotificationDetails getNotificationDetailsForType(String type) {
    switch (type) {
      case 'subscription_approved':
      case 'subscription_activated':
      case 'free_subscription_granted':
        return getSuccessNotificationDetails();

      case 'restriction':
      case 'student_restricted':
        return getCriticalNotificationDetails();

      case 'attendance_marked':
      case 'class_created':
        return getGeneralNotificationDetails();

      default:
        return getGeneralNotificationDetails();
    }
  }

  /// Critical notifications (red theme)
  AndroidNotificationDetails getCriticalNotificationDetails() {
    return AndroidNotificationDetails(
      criticalChannel.id,
      criticalChannel.name,
      channelDescription: criticalChannel.description,
      importance: criticalChannel.importance,
      color: Colors.red,
      colorized: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
      actions: [
        const AndroidNotificationAction('view_details', 'View Details'),
        const AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );
  }

  /// Success notifications (green theme)
  AndroidNotificationDetails getSuccessNotificationDetails() {
    return AndroidNotificationDetails(
      successChannel.id,
      successChannel.name,
      channelDescription: successChannel.description,
      importance: successChannel.importance,
      color: Colors.green,
      colorized: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  /// General notifications (blue theme)
  AndroidNotificationDetails getGeneralNotificationDetails() {
    return AndroidNotificationDetails(
      generalChannel.id,
      generalChannel.name,
      channelDescription: generalChannel.description,
      importance: generalChannel.importance,
      color: Colors.blue,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request FCM permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Permission status: ${settings.authorizationStatus}');

      // Request Android 13+ notification permissions
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  /// Set up Firebase Cloud Messaging
  Future<void> _setupFirebaseMessaging() async {
    try {
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // TODO: Send token to server
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Handle initial message if app was launched from notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      debugPrint('Error setting up Firebase Messaging: $e');
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_notificationsEnabled) return;

    debugPrint('Foreground message received: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      final type = data['type'] as String? ?? 'general';
      final androidDetails = getNotificationDetailsForType(type);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notification.title ?? 'Notification',
        notification.body ?? '',
        NotificationDetails(android: androidDetails),
        payload: json.encode(data),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    
    // TODO: Navigate to appropriate screen based on notification data
    // You can use message.data to determine which screen to open
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    // TODO: Handle navigation based on payload
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
    String type = 'general',
  }) async {
    final androidDetails = getNotificationDetailsForType(type);
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('Notification shown - ID: $id, Title: $title, Body: $body, Type: $type');
  }

  /// Show custom notification (for backward compatibility)
  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    Map<String, dynamic>? data,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('Notifications disabled');
      return;
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: data?.toString(),
      id: id,
    );
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await _requestPermissions();
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Show smart notification with enhanced features
  Future<void> showSmartNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
    List<String>? inboxLines,
  }) async {
    if (!_notificationsEnabled) return;

    final type = data['type'] as String? ?? 'general';
    AndroidNotificationDetails androidDetails = getNotificationDetailsForType(type);

    // Add image if provided
    if (imageUrl != null && imageUrl.isNotEmpty) {
      androidDetails = AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        color: androidDetails.color,
        colorized: androidDetails.colorized,
        largeIcon: androidDetails.largeIcon,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(imageUrl),
          contentTitle: title,
          summaryText: body,
        ),
      );
    }

    // Add inbox style if multiple lines provided
    if (inboxLines != null && inboxLines.isNotEmpty) {
      androidDetails = AndroidNotificationDetails(
        androidDetails.channelId,
        androidDetails.channelName,
        channelDescription: androidDetails.channelDescription,
        importance: androidDetails.importance,
        priority: androidDetails.priority,
        color: androidDetails.color,
        colorized: androidDetails.colorized,
        largeIcon: androidDetails.largeIcon,
        styleInformation: InboxStyleInformation(
          inboxLines,
          contentTitle: title,
          summaryText: '${inboxLines.length} new items',
        ),
      );
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: json.encode(data),
    );
  }

  /// Schedule notification (for future use)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    int id = 0,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('Notifications disabled - will not schedule');
      return;
    }

    debugPrint('Scheduled Notification: $title - $body at $scheduledDate');
    // TODO: Implement with timezone package if needed
  }

  bool get isEnabled => _notificationsEnabled;
}
