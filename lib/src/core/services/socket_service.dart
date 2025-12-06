import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final _locationController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:3000';
    print('🔌 Connecting to Socket.IO at $baseUrl');
    
    if (_socket != null && _socket!.connected) {
      print('⚠️ Socket already connected');
      return;
    }

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .enableAutoConnect()
        .build());

    _socket!.onConnect((_) {
      print('✅ Socket connected successfully: ${_socket?.id}');
    });

    _socket!.onConnectError((data) {
      print('❌ Socket connection error: $data');
    });

    _socket!.onError((data) {
      print('❌ Socket error: $data');
    });

    _socket!.onDisconnect((_) {
      print('⚠️ Socket disconnected');
    });

    _socket!.on('locationUpdated', (data) {
      print('📍 Location update received via socket: $data');
      _locationController.add(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('joined', (data) {
      print('🚪 Joined room: $data');
    });
  }

  void joinChildRoom(String childId) {
    if (_socket != null && _socket!.connected) {
      print('📤 Emitting joinChildRoom for $childId');
      _socket!.emit('joinChildRoom', {'childId': childId});
    } else {
      print('❌ Cannot join room: Socket not connected');
    }
  }

  void leaveChildRoom(String childId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leaveChildRoom', {'childId': childId});
    }
  }

  // Method to simulate child sending location (for testing)
  void emitLocationUpdate(String childId, double lat, double lng, double battery, String status) {
    if (_socket != null && _socket!.connected) {
      print('📤 Emitting updateLocation for $childId: $lat, $lng');
      _socket!.emit('updateLocation', {
        'childId': childId,
        'lat': lat,
        'lng': lng,
        'battery': battery,
        'status': status,
      });
    } else {
      print('❌ Cannot emit location: Socket not connected');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
