import '../entities/child.dart';

abstract class ChildrenRepository {
  Future<List<Child>> getChildren();
  Future<Child?> getChildById(String id);
  Future<Child> createChild({
    required String name,
    String? lastName,
    String? phone,
  });
  Future<void> deleteChild(String id);
  Future<Child> updateChild(String id, Map<String, dynamic> data);
  Future<Child> updateChildLocation(
    String id,
    double latitude,
    double longitude,
  );
  Future<void> removeChildFromTutor(String tutorId, String childId);
  Future<String> regenerateCode(String childId);
}
