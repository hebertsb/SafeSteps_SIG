import '../entities/alert.dart';

abstract class AlertsRepository {
  Stream<List<Alert>> getAlerts();
  Future<void> markAsRead(String id);
}
