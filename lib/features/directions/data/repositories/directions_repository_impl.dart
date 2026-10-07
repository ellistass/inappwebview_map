import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';
import '../datasources/directions_remote_datasource.dart';

class DirectionsRepositoryImpl implements DirectionsRepository {
  final DirectionsRemoteDataSource _dataSource;

  const DirectionsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, DirectionsEntity>> getDirections(
    RequestParam params,
  ) async {
    try {
      final result = await _dataSource.getDirections(params);
      if (!result.hasRoutes) {
        return const Left(ServerFailure('No routes found'));
      }
      return Right(result);
    } on DirectionsTimeoutException catch (e) {
      return Left(
        ServerFailure(
          'Google Maps took too long to respond. Stuck on: ${e.page}',
        ),
      );
    } on FormatException catch (e) {
      return Left(ParseFailure('Unexpected directions format: ${e.message}'));
    } on TypeError catch (e) {
      return Left(ParseFailure('Unexpected directions format: $e'));
    }
  }
}
