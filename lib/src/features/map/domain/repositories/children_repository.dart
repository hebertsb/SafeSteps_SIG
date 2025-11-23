import '../entities/child.dart';

abstract class ChildrenRepository {
  Future<List<Child>> getChildren();
  Future<Child?> getChildById(String id);
}
