import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../repositories/location_repository.dart';

class EnsureLocationPermissionUseCase {
  final LocationRepository _repository;

  const EnsureLocationPermissionUseCase(this._repository);

  Future<Either<Failure, Unit>> call() => _repository.ensurePermission();
}
