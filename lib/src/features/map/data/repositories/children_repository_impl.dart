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
}
