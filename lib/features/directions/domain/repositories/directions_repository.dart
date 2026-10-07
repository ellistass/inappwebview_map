import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../entities/directions_entity.dart';

abstract class DirectionsRepository {
  Future<Either<Failure, DirectionsEntity>> getDirections(RequestParam params);
}
