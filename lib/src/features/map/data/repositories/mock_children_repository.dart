import '../../domain/entities/child.dart';
import '../../domain/repositories/children_repository.dart';

class MockChildrenRepository implements ChildrenRepository {
  @override
  Future<List<Child>> getChildren() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      Child(
        id: '1',
        name: 'Miguel',
        age: 8,
        emoji: '👦',
        phone: '+34 612 345 678',
        device: 'iPhone 12',
        status: 'online',
        battery: 85.0,
        latitude: -17.7833, // Santa Cruz
        longitude: -63.1821,
        lastUpdated: DateTime.now(),
      ),
    ];
  }

  @override
  Future<Child?> getChildById(String id) async {
    final children = await getChildren();
    try {
      return children.firstWhere((child) => child.id == id);
    } catch (e) {
      return null;
    }
  }
}
