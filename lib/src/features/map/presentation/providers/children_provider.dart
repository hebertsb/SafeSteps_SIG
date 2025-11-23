import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/child.dart';
import '../../domain/repositories/children_repository.dart';
import '../../data/repositories/mock_children_repository.dart';

// 1. Provider for the Repository (Dependency Injection)
final childrenRepositoryProvider = Provider<ChildrenRepository>((ref) {
  return MockChildrenRepository();
});

// 2. Provider for the Data (State Management)
final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final repository = ref.read(childrenRepositoryProvider);
  return repository.getChildren();
});
