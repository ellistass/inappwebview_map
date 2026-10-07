import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';
import '../datasources/location_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource _dataSource;

  const LocationRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, Unit>> ensurePermission() async {
    try {
      await _dataSource.ensurePermission();
      return const Right(unit);
    } on LocationAccessException catch (e) {
      return Left(LocationFailure(e.message));
    }
  }

  @override
  Stream<UserLocationEntity> watchLocation() => _dataSource.watch();

  @override
  Future<Either<Failure, UserLocationEntity>> getCurrentLocation() async {
    try {
      return Right(await _dataSource.current());
    } on LocationAccessException catch (e) {
      return Left(LocationFailure(e.message));
    }
  }
}
