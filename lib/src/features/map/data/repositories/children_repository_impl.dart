import '../../domain/entities/child.dart';
import '../../domain/repositories/children_repository.dart';
import '../datasources/remote_children_data_source.dart';

class ChildrenRepositoryImpl implements ChildrenRepository {
  final RemoteChildrenDataSource _dataSource;

  ChildrenRepositoryImpl(this._dataSource);

  @override
  Future<List<Child>> getChildren() async {
    return await _dataSource.getChildren();
  }

  @override
  Future<Child?> getChildById(String id) async {
    try {
      return await _dataSource.getChildById(id);
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
    return await _dataSource.createChild(
      name: name,
      email: email,
      password: password,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> deleteChild(String id) async {
    await _dataSource.deleteChild(id);
  }

  @override
  Future<Child> updateChild(String id, Map<String, dynamic> data) async {
    return await _dataSource.updateChild(id, data);
  }

  @override
  Future<Child> updateChildLocation(String id, double latitude, double longitude) async {
    return await _dataSource.updateChildLocation(id, latitude, longitude);
  }

  @override
  Future<void> removeChildFromTutor(String tutorId, String childId) async {
    await _dataSource.removeChildFromTutor(tutorId, childId);
  }
}
