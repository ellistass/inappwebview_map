import 'package:geolocator/geolocator.dart';

import '../../domain/domain.dart';

class UserLocationModel extends UserLocationEntity {
  const UserLocationModel({
    required super.position,
    required super.accuracy,
    super.heading,
    super.speed,
  });

  factory UserLocationModel.fromPosition(Position p) {
    return UserLocationModel(
      position: LatLngEntity(p.latitude, p.longitude),
      accuracy: p.accuracy,
      // Geolocator reports 0 / negative when heading is unknown.
      heading: p.heading > 0 ? p.heading : null,
      speed: p.speed < 0 ? 0 : p.speed,
    );
  }
}
