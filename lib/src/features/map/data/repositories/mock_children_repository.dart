import '../../domain/entities/child.dart';
import '../../domain/repositories/children_repository.dart';

class MockChildrenRepository implements ChildrenRepository {
  @override
  Future<List<Child>> getChildren() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      Child(
        id: '17',
        name: 'Hijo Uno P1',
        age: 8,
        emoji: '👦',
        phone: '+34 612 345 678',
        device: 'Emulator',
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


  @override
  Future<Child> createChild({
    required String name,
    required String email,
    required String password,
    double? latitude,
    double? longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return Child(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      age: 0,
      emoji: '👶',
      phone: '',
      device: 'Unknown',
      status: 'offline',
      battery: 100.0,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
      lastUpdated: DateTime.now(),
    );
  }
  @override
  Future<void> deleteChild(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<Child> updateChild(String id, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (await getChildren()).first;
  }

  @override
  Future<Child> updateChildLocation(String id, double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return (await getChildren()).first;
  }

  @override
  Future<void> removeChildFromTutor(String tutorId, String childId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
