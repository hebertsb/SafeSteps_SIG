import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';

// Singleton instance of SocketService
// Se mantiene una única instancia pero se puede reconectar con diferentes tokens
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// Provider para forzar reconexión cuando cambia el usuario
final socketConnectionProvider = Provider.autoDispose<void>((ref) {
  // Este provider se puede usar para forzar reconexión
  return;
});
