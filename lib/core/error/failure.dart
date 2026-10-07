import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Google didn't answer in time, or the page never produced a route response.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// A response came back but its shape wasn't what the parser expects.
class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

/// Location permission denied or the location service is off.
class LocationFailure extends Failure {
  const LocationFailure(super.message);
}
