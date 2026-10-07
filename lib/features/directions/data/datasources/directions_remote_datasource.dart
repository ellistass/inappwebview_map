import '../../../../core/core.dart';
import '../models/directions_model.dart';

abstract class DirectionsRemoteDataSource {
  /// Throws [DirectionsTimeoutException] when no route response arrives, and
  /// [FormatException] when one arrives but can't be parsed.
  Future<DirectionsModel> getDirections(RequestParam params);
}

/// No route response arrived in time. [page] says what the hidden page was
/// showing instead; [trail] lists its loads and errors.
class DirectionsTimeoutException implements Exception {
  final String page;
  final List<String> trail;

  const DirectionsTimeoutException(this.page, this.trail);

  @override
  String toString() => 'DirectionsTimeoutException: $page\n${trail.join('\n')}';
}
