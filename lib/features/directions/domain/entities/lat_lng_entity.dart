import 'dart:math' as math;

import 'package:equatable/equatable.dart';

class LatLngEntity extends Equatable {
  final double lat;
  final double lng;

  const LatLngEntity(this.lat, this.lng);

  /// Great-circle distance in metres.
  double distanceTo(LatLngEntity other) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Point [t] (0–1) of the way to [other]; fine at street scale.
  LatLngEntity lerp(LatLngEntity other, double t) =>
      LatLngEntity(lat + (other.lat - lat) * t, lng + (other.lng - lng) * t);

  /// The point [meters] away heading [bearing] degrees from north.
  LatLngEntity offset(double bearing, double meters) {
    final b = bearing * math.pi / 180;
    final dLat = meters * math.cos(b) / 111320;
    final dLng =
        meters * math.sin(b) / (111320 * math.cos(lat * math.pi / 180));
    return LatLngEntity(lat + dLat, lng + dLng);
  }

  LatLngEntity copyWith({double? lat, double? lng}) =>
      LatLngEntity(lat ?? this.lat, lng ?? this.lng);

  @override
  String toString() => '$lat,$lng';

  @override
  List<Object?> get props => [lat, lng];
}
