import 'package:equatable/equatable.dart';

import 'lat_lng_entity.dart';

class UserLocationEntity extends Equatable {
  final LatLngEntity position;

  /// Degrees clockwise from north; null when the device isn't moving.
  final double? heading;

  /// Metres per second.
  final double speed;

  /// Horizontal accuracy radius in metres.
  final double accuracy;

  const UserLocationEntity({
    required this.position,
    required this.accuracy,
    this.heading,
    this.speed = 0,
  });

  /// Below ~1 m/s GPS heading is noise.
  bool get isMoving => speed > 1;

  UserLocationEntity copyWith({
    LatLngEntity? position,
    double? heading,
    double? speed,
    double? accuracy,
  }) {
    return UserLocationEntity(
      position: position ?? this.position,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  @override
  List<Object?> get props => [position, heading, speed, accuracy];
}
