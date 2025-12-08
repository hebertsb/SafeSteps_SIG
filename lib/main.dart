import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/services/background_location_service.dart';
import 'src/features/notifications/data/services/fcm_service.dart';
import 'src/features/notifications/presentation/providers/notifications_provider.dart';
import 'src/features/notifications/domain/entities/app_notification.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isInitialized = false;
  String _status = 'Iniciando...';
  String? _error;
  FCMService? _fcmService;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'Cargando configuración...');
      await dotenv.load(fileName: ".env");

      setState(() => _status = 'Conectando servicios...');
      await Firebase.initializeApp();

      // NOTE: BackgroundLocationService is now initialized lazily when child logs in
      // to avoid notification channel issues on Android 13+

      setState(() => _status = 'Iniciando notificaciones...');
      _fcmService = FCMService();
      // Add timeout to prevent infinite hang
      await _fcmService!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('FCM initialization timed out, continuing anyway...');
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      print('Initialization error: $e');
      print(stack);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = 'Error al iniciar';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error de inicialización',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initializeApp,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_status),
              ],
            ),
          ),
        ),
      );
    }

    return ProviderScope(child: MyApp(fcmService: _fcmService!));
  }
}

class MyApp extends ConsumerStatefulWidget {
  final FCMService fcmService;

  const MyApp({super.key, required this.fcmService});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
        isLocal: true,
      );

      // Add locally for immediate feedback
      ref.read(notificationsProvider.notifier).addNotification(notification);
      
      // Also refresh from backend to get any historical/other updates
      ref.read(notificationsProvider.notifier).refresh();

      // Show SnackBar for foreground notifications
      if (mounted && message.notification != null) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.notification!.title ?? 'Notificación',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(message.notification!.body ?? ''),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'VER',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to notifications screen if needed
                // context.push('/notifications');
              },
            ),
          ),
        );
      }
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
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
