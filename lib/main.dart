import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/notifications/data/services/fcm_service.dart';
import 'src/features/notifications/presentation/providers/notifications_provider.dart';
import 'src/features/notifications/domain/entities/app_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  
  // Initialize FCM
  final fcmService = FCMService();
  await fcmService.initialize();
  
  runApp(ProviderScope(
    child: MyApp(fcmService: fcmService),
  ));
}

class MyApp extends ConsumerStatefulWidget {
  final FCMService fcmService;
  
  const MyApp({super.key, required this.fcmService});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Listen to FCM messages and add to notifications
    widget.fcmService.onMessage.listen((message) {
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? 'SafeSteps',
        body: message.notification?.body ?? '',
        timestamp: DateTime.now(),
        type: _getNotificationType(message.data),
        data: message.data,
      );
      
      ref.read(notificationsProvider.notifier).addNotification(notification);
    });
  }
  
  NotificationType _getNotificationType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'zone_entry':
        return NotificationType.zoneEntry;
      case 'zone_exit':
        return NotificationType.zoneExit;
      case 'low_battery':
        return NotificationType.lowBattery;
      case 'alert':
        return NotificationType.alert;
      default:
        return NotificationType.general;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'SafeSteps',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
