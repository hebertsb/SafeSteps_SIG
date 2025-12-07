import 'dart:developer';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vibration/vibration.dart';
import '../../../sos/data/sos_service.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('Handling background message: ${message.messageId}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    print('🔥 Initializing FCM Service...');
    
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('🔥 FCM Authorization Status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ User granted provisional permission');
    } else {
      print('❌ User declined or has not accepted permission');
      return;
    }

    // Get FCM token
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('🔥 FCM Token: $_fcmToken');
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }

    // Configure foreground notification presentation
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('🔥 Foreground message received: ${message.notification?.title}');
      print('🔥 Message data: ${message.data}');
      
      final type = message.data['type'];
      if (type == 'sos_panico') {
        print('🚨 SOS Alert received! Triggering alarm...');
        await SOSService.vibrarPatronSOS();
        await SOSService.reproducirSonidoSOS();
      } else {
        // Standard vibration for other notifications
        if (await Vibration.hasVibrator() ?? false) {
           await Vibration.vibrate(duration: 500);
        }
      }
      
      _messageStreamController.add(message);
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔥 Notification tapped: ${message.data}');
      _messageStreamController.add(message);
    });

    // Handle notification tap when app was terminated
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔥 App opened from terminated state: ${initialMessage.data}');
      _messageStreamController.add(initialMessage);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('🔥 FCM Token refreshed: $newToken');
    });
  }

  void dispose() {
    _messageStreamController.close();
  }
}
