import 'dart:async';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alerts_repository.dart';

class MockAlertsRepository implements AlertsRepository {
  final _controller = StreamController<List<Alert>>.broadcast();
  final List<Alert> _currentAlerts = [
    Alert(
      id: '1',
      title: 'Llegada al Colegio',
      message: 'Miguel ha llegado al Colegio',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      read: false,
      type: 'zone_enter',
    ),
    Alert(
      id: '2',
      title: 'Batería Baja',
      message: 'La batería de Miguel está por debajo del 15%',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      read: true,
      type: 'battery',
    ),
  ];

  MockAlertsRepository() {
    // Emit initial value
    _controller.add(_currentAlerts);

    // Simulate a new alert coming in after 5 seconds
    Timer(const Duration(seconds: 5), () {
      _currentAlerts.insert(0, Alert(
        id: '3',
        title: 'Salida de Zona Segura',
        message: 'Miguel ha salido de la zona "Casa"',
        timestamp: DateTime.now(),
        read: false,
        type: 'zone_exit',
      ));
      _controller.add(List.from(_currentAlerts));
    });
  }

  @override
  Stream<List<Alert>> getAlerts() {
    return _controller.stream;
  }

  @override
  Future<void> markAsRead(String id) async {
    // Mock implementation
  }
}
