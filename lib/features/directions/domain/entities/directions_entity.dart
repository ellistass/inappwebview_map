import 'package:equatable/equatable.dart';

import 'lat_lng_entity.dart';
import 'route_entity.dart';

class DirectionsEntity extends Equatable {
  final String originName;
  final String destinationName;
  final LatLngEntity? origin;
  final LatLngEntity? destination;

  /// Recommended route first, then alternatives.
  final List<RouteEntity> routes;

  const DirectionsEntity({
    required this.originName,
    required this.destinationName,
    required this.routes,
    this.origin,
    this.destination,
  });

  bool get hasRoutes => routes.isNotEmpty;
  RouteEntity? get primary => routes.isEmpty ? null : routes.first;
  List<RouteEntity> get alternatives => routes.skip(1).toList();

  /// Where to pin route [index]'s ETA bubble: the point on it farthest from
  /// every other route, so bubbles sit where the routes diverge rather than
  /// stacking on a shared stretch.
  LatLngEntity? labelPointFor(int index) {
    if (index < 0 || index >= routes.length) return null;
    final own = routes[index].polyline;
    if (own.isEmpty) return null;
    if (routes.length == 1) return own[own.length ~/ 2];

    List<LatLngEntity> sample(List<LatLngEntity> pts) {
      final step = (pts.length / 80).ceil().clamp(1, pts.length);
      return [for (var i = 0; i < pts.length; i += step) pts[i]];
    }

    final others = [
      for (var i = 0; i < routes.length; i++)
        if (i != index) ...sample(routes[i].polyline),
    ];
    // Skip the first/last 10% — routes always meet at the endpoints.
    final candidates = sample(
      own.sublist(own.length ~/ 10, own.length * 9 ~/ 10),
    );
    LatLngEntity? best;
    var bestDistance = -1.0;
    for (final c in candidates) {
      var nearest = double.infinity;
      for (final o in others) {
        final dLat = c.lat - o.lat, dLng = c.lng - o.lng;
        final d = dLat * dLat + dLng * dLng;
        if (d < nearest) nearest = d;
      }
      if (nearest > bestDistance) {
        bestDistance = nearest;
        best = c;
      }
    }
    return best ?? own[own.length ~/ 2];
  }

  DirectionsEntity copyWith({
    String? originName,
    String? destinationName,
    LatLngEntity? origin,
    LatLngEntity? destination,
    List<RouteEntity>? routes,
  }) {
    return DirectionsEntity(
      originName: originName ?? this.originName,
      destinationName: destinationName ?? this.destinationName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      routes: routes ?? this.routes,
    );
  }

  @override
  List<Object?> get props => [
    originName,
    destinationName,
    origin,
    destination,
    routes,
  ];
}
