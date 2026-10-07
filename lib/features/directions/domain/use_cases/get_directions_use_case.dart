import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../entities/directions_entity.dart';
import '../repositories/directions_repository.dart';

class GetDirectionsUseCase {
  final DirectionsRepository _repository;

  const GetDirectionsUseCase(this._repository);

  Future<Either<Failure, DirectionsEntity>> call(RequestParam params) {
    return _repository.getDirections(params);
  }
}
