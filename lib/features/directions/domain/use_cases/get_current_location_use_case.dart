import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../entities/user_location_entity.dart';
import '../repositories/location_repository.dart';

class GetCurrentLocationUseCase {
  final LocationRepository _repository;

  const GetCurrentLocationUseCase(this._repository);

  Future<Either<Failure, UserLocationEntity>> call() =>
      _repository.getCurrentLocation();
}
