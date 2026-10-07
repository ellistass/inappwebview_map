import '../models/user_location_model.dart';

abstract class LocationDataSource {
  /// Throws [LocationAccessException] when permission is denied or the
  /// location service is off.
  Future<void> ensurePermission();

  Stream<UserLocationModel> watch();

  /// Throws [LocationAccessException] on denied permission or no fix.
  Future<UserLocationModel> current();
}

class LocationAccessException implements Exception {
  final String message;
  const LocationAccessException(this.message);
}
