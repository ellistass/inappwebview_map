import 'package:fpdart/fpdart.dart';

import '../../../../core/core.dart';
import '../entities/user_location_entity.dart';

abstract class LocationRepository {
  /// Asks for permission if needed; Left when denied or location is off.
  Future<Either<Failure, Unit>> ensurePermission();

  Stream<UserLocationEntity> watchLocation();

  /// One fresh fix; Left when permission is denied or no fix arrives.
  Future<Either<Failure, UserLocationEntity>> getCurrentLocation();
}
