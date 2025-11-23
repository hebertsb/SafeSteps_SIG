import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../../data/repositories/mock_alerts_repository.dart';

final alertsRepositoryProvider = Provider<AlertsRepository>((ref) {
  return MockAlertsRepository();
});

final alertsProvider = StreamProvider<List<Alert>>((ref) {
  final repository = ref.read(alertsRepositoryProvider);
  return repository.getAlerts();
});
