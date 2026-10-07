import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'lat_lng_entity.dart';
import 'route_step_entity.dart';
import 'traffic_span_entity.dart';

/// Where a position sits relative to a route.
typedef RouteFix = ({
  /// Metres travelled along the route to the snapped point.
  double alongMeters,

  /// Distance from the raw position to the route.
  double offsetMeters,

  /// The position projected onto the route.
  LatLngEntity snapped,
});

/// A slice of the route drawn in one traffic colour.
typedef TrafficPath = ({TrafficLevel level, List<LatLngEntity> points});

class RouteEntity extends Equatable {
  /// Position in Google's list; 0 is the recommended route.
  final int index;

  /// The "via" label, e.g. "Expressway1/E1".
  final String summary;

  final int distanceMeters;
  final String distanceText;

  /// Free-flow duration (no traffic).
  final int durationSeconds;
  final String durationText;

  /// Duration with current traffic — what Google shows as the headline ETA.
  final int? durationInTrafficSeconds;
  final String? durationInTrafficText;

  /// Typical range, e.g. "37 min to 1 hr 13 min".
  final String? durationRangeText;

  final List<RouteStepEntity> steps;

  /// Path to draw. Road-following when [hasDetailedPolyline] is true (desktop
  /// response), otherwise only origin → maneuver points → destination.
  final List<LatLngEntity> polyline;
  final bool hasDetailedPolyline;

  /// Slow/heavy stretches; everything else is free-flowing.
  final List<TrafficSpanEntity> trafficSpans;

  const RouteEntity({
    required this.index,
    required this.summary,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.steps,
    required this.polyline,
    required this.hasDetailedPolyline,
    this.durationInTrafficSeconds,
    this.durationInTrafficText,
    this.durationRangeText,
    this.trafficSpans = const [],
  });

  bool get isAlternative => index > 0;

  /// The ETA Google headlines: traffic-aware when available.
  int get etaSeconds => durationInTrafficSeconds ?? durationSeconds;
  String get etaText => durationInTrafficText ?? durationText;

  /// Extra time traffic adds over free-flow.
  int get trafficDelaySeconds => etaSeconds - durationSeconds;
  bool get hasTrafficDelay => trafficDelaySeconds >= 5 * 60;

  /// Metres from the start to each polyline point.
  List<double> get cumulativeMeters {
    final out = <double>[0];
    for (var i = 1; i < polyline.length; i++) {
      out.add(out.last + polyline[i - 1].distanceTo(polyline[i]));
    }
    return out;
  }

  /// Metres from the start to where each step begins.
  List<int> get stepStartMeters {
    var acc = 0;
    return [
      for (final s in steps) (acc += s.distanceMeters) - s.distanceMeters,
    ];
  }

  /// Index of the step being driven at [alongMeters].
  int stepIndexAt(double alongMeters) {
    final starts = stepStartMeters;
    var i = 0;
    while (i + 1 < starts.length && starts[i + 1] <= alongMeters) {
      i++;
    }
    return i;
  }

  /// The point [meters] along the route.
  LatLngEntity pointAt(double meters, [List<double>? cumulative]) {
    final cum = cumulative ?? cumulativeMeters;
    if (meters <= 0) return polyline.first;
    if (meters >= cum.last) return polyline.last;
    var i = 1;
    while (cum[i] < meters) {
      i++;
    }
    final span = cum[i] - cum[i - 1];
    final t = span == 0 ? 0.0 : (meters - cum[i - 1]) / span;
    return polyline[i - 1].lerp(polyline[i], t);
  }

  /// Points between [fromMeters] and [toMeters], cut exactly at both ends.
  List<LatLngEntity> slice(
    double fromMeters,
    double toMeters, [
    List<double>? cumulative,
  ]) {
    final cum = cumulative ?? cumulativeMeters;
    return [
      pointAt(fromMeters, cum),
      for (var i = 0; i < polyline.length; i++)
        if (cum[i] > fromMeters && cum[i] < toMeters) polyline[i],
      pointAt(toMeters, cum),
    ];
  }

  /// The route split into traffic-coloured slices.
  List<TrafficPath> get trafficPaths {
    if (polyline.length < 2) return const [];
    final cum = cumulativeMeters;
    return [
      for (final span in trafficSpans)
        (
          level: span.level,
          points: slice(
            span.startMeters.toDouble(),
            span.endMeters.toDouble(),
            cum,
          ),
        ),
    ];
  }

  /// Snaps [position] to the nearest point on the route. Searching from
  /// [hintMeters] (last known progress) keeps it from jumping onto a
  /// parallel stretch further along.
  RouteFix locate(LatLngEntity position, {double? hintMeters}) {
    final cum = cumulativeMeters;
    // Local equirectangular projection, metres; accurate at street scale.
    final kLat = 111320.0;
    final kLng = 111320.0 * math.cos(position.lat * math.pi / 180);
    var best = (
      alongMeters: 0.0,
      offsetMeters: double.infinity,
      snapped: polyline.first,
    );
    for (var i = 1; i < polyline.length; i++) {
      if (hintMeters != null &&
          (cum[i] < hintMeters - 200 || cum[i - 1] > hintMeters + 2000)) {
        continue;
      }
      final a = polyline[i - 1], b = polyline[i];
      final bx = (b.lng - a.lng) * kLng, by = (b.lat - a.lat) * kLat;
      final px = (position.lng - a.lng) * kLng,
          py = (position.lat - a.lat) * kLat;
      final len2 = bx * bx + by * by;
      final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
      final dx = px - bx * t, dy = py - by * t;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < best.offsetMeters) {
        best = (
          alongMeters: cum[i - 1] + (cum[i] - cum[i - 1]) * t,
          offsetMeters: d,
          snapped: a.lerp(b, t),
        );
      }
    }
    // Hint window missed entirely (e.g. after a jump) — search everything.
    if (hintMeters != null && best.offsetMeters > 100) return locate(position);
    return best;
  }

  /// Direction of travel at [alongMeters], degrees clockwise from north,
  /// looking a little ahead so the camera doesn't twitch on tiny segments.
  double bearingAt(double alongMeters, {double lookAhead = 40}) {
    final cum = cumulativeMeters;
    final from = pointAt(alongMeters, cum);
    final to = pointAt(alongMeters + lookAhead, cum);
    final y =
        math.sin((to.lng - from.lng) * math.pi / 180) *
        math.cos(to.lat * math.pi / 180);
    final x =
        math.cos(from.lat * math.pi / 180) * math.sin(to.lat * math.pi / 180) -
        math.sin(from.lat * math.pi / 180) *
            math.cos(to.lat * math.pi / 180) *
            math.cos((to.lng - from.lng) * math.pi / 180);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Seconds left from [alongMeters], scaled from the traffic-aware ETA.
  int remainingSecondsAt(double alongMeters) {
    if (distanceMeters == 0) return 0;
    final left = (distanceMeters - alongMeters).clamp(0, distanceMeters);
    return (etaSeconds * left / distanceMeters).round();
  }

  RouteEntity copyWith({
    int? index,
    String? summary,
    int? distanceMeters,
    String? distanceText,
    int? durationSeconds,
    String? durationText,
    int? durationInTrafficSeconds,
    String? durationInTrafficText,
    String? durationRangeText,
    List<RouteStepEntity>? steps,
    List<LatLngEntity>? polyline,
    bool? hasDetailedPolyline,
    List<TrafficSpanEntity>? trafficSpans,
  }) {
    return RouteEntity(
      index: index ?? this.index,
      summary: summary ?? this.summary,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      distanceText: distanceText ?? this.distanceText,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationText: durationText ?? this.durationText,
      durationInTrafficSeconds:
          durationInTrafficSeconds ?? this.durationInTrafficSeconds,
      durationInTrafficText:
          durationInTrafficText ?? this.durationInTrafficText,
      durationRangeText: durationRangeText ?? this.durationRangeText,
      steps: steps ?? this.steps,
      polyline: polyline ?? this.polyline,
      hasDetailedPolyline: hasDetailedPolyline ?? this.hasDetailedPolyline,
      trafficSpans: trafficSpans ?? this.trafficSpans,
    );
  }

  @override
  List<Object?> get props => [
    index,
    summary,
    distanceMeters,
    distanceText,
    durationSeconds,
    durationText,
    durationInTrafficSeconds,
    durationInTrafficText,
    durationRangeText,
    steps,
    polyline,
    hasDetailedPolyline,
    trafficSpans,
  ];
}
