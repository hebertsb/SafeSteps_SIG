import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

/// Background location service that runs even when the app is closed.
/// Sends location updates via WebSocket to the backend.
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._();
  static BackgroundLocationService get instance => _instance;
  
  BackgroundLocationService._();
  
  final FlutterBackgroundService _service = FlutterBackgroundService();
  
  static const String _notificationChannelId = 'safesteps_location_channel';
  static const String _notificationChannelName = 'SafeSteps Ubicación';
  
  /// Initialize the background service. Call this once at app startup.
  Future<void> initialize() async {
    // Create notification channel for Android
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Canal para el seguimiento de ubicación en segundo plano',
      importance: Importance.low, // Low importance = no sound
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'SafeSteps',
        initialNotificationContent: 'Compartiendo ubicación con tus padres',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }
  
  /// Start background tracking with the given auth token
  Future<bool> startService(String token) async {
    // Save token to shared preferences so background isolate can access it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_auth_token', token);
    
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('updateToken', {'token': token});
      return true;
    }
    
    return await _service.startService();
  }
  
  /// Stop the background service
  Future<void> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_auth_token');
    _service.invoke('stopService');
  }
  
  /// Check if service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
  
  /// Listen to service status updates
  Stream<Map<String, dynamic>?> get onServiceData => _service.on('update');
}

// ============================================================================
// ISOLATE ENTRY POINTS (Run in separate isolate/process)
// ============================================================================

/// Entry point for background service on both platforms
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  io.Socket? socket;
  String? authToken;
  StreamSubscription<Position>? positionSubscription;
  String? apiUrl;
  
  // Load token and config from shared preferences
  final prefs = await SharedPreferences.getInstance();
  authToken = prefs.getString('bg_auth_token');
  
  // Load environment - use default if can't load
  try {
    await dotenv.load(fileName: ".env");
    apiUrl = dotenv.env['API_URL'];
  } catch (e) {
    debugPrint('Could not load .env in background: $e');
  }
  apiUrl ??= 'http://10.0.2.2:3000';
  
  debugPrint(' Background service started');
  debugPrint(' Token available: ${authToken != null}');
  debugPrint(' API URL: $apiUrl');
  
  /// Connect to WebSocket server
  void connectSocket() {
    if (authToken == null) {
      debugPrint(' Cannot connect socket: no auth token');
      return;
    }
    
    debugPrint(' Background connecting to $apiUrl');
    
    socket?.disconnect();
    socket?.dispose();
    
    socket = io.io(
      apiUrl!,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .setAuth({'token': authToken})
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );
    
    socket!.onConnect((_) {
      debugPrint(' Background socket connected');
      service.invoke('update', {'status': 'connected'});
    });
    
    socket!.onDisconnect((_) {
      debugPrint(' Background socket disconnected');
      service.invoke('update', {'status': 'disconnected'});
    });
    
    socket!.onError((e) {
      debugPrint(' Background socket error: $e');
    });
  }
  
  /// Start location tracking
  Future<void> startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      debugPrint(' Location permission denied in background');
      return;
    }
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint(' Location service disabled');
      return;
    }
    
    await positionSubscription?.cancel();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        debugPrint(' BG location: ${position.latitude}, ${position.longitude}');
        
        int batteryLevel = 100;
        try {
          final battery = Battery();
          batteryLevel = await battery.batteryLevel;
        } catch (e) {
          // Ignore battery errors
        }
        
        if (socket != null && socket!.connected) {
          socket!.emit('updateLocation', {
            'lat': position.latitude,
            'lng': position.longitude,
            'battery': batteryLevel.toDouble(),
            'status': 'Activo (segundo plano)',
          });
          debugPrint(' BG location emitted');
        } else {
          debugPrint(' Socket not connected, reconnecting...');
          connectSocket();
        }
        
        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'SafeSteps - Activo',
            content: 'Batería: $batteryLevel% | ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          );
        }
        
        service.invoke('update', {
          'lat': position.latitude,
          'lng': position.longitude,
          'battery': batteryLevel,
        });
      },
      onError: (error) {
        debugPrint(' BG location error: $error');
      },
    );
    
    debugPrint(' Location tracking started');
  }
  
  // Handle token updates from main app
  service.on('updateToken').listen((event) async {
    authToken = event?['token'];
    if (authToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bg_auth_token', authToken!);
    }
    debugPrint(' Token updated');
    connectSocket();
  });
  
  // Handle stop command
  service.on('stopService').listen((event) async {
    debugPrint(' Stopping background service');
    
    if (socket != null && socket!.connected) {
      socket!.emit('childOffline', {});
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    await positionSubscription?.cancel();
    socket?.disconnect();
    socket?.dispose();
    await service.stopSelf();
  });
  
  // For Android foreground service
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
  }
  
  // Start if we have a token
  if (authToken != null) {
    connectSocket();
    await startLocationTracking();
  } else {
    debugPrint(' No token available, waiting for updateToken');
  }
}

/// iOS background mode handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
