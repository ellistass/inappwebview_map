import 'dart:convert';

import '../../domain/domain.dart';

/// Parses the body of Google Maps' internal `/maps/preview/directions` response.
///
/// The payload is a positional JSON array (no keys) prefixed with `)]}'`. Index
/// paths below were mapped from captured responses (Oct 2026) and can change
/// whenever Google ships a new frontend — every lookup is null-safe so a shift
/// degrades to missing fields rather than a crash.
///
/// Layout (d = decoded array):
///   d[0][0][k]                waypoint k: [4] query text, [0][0][2] = (_, _, lat, lng)
///   d[0][1][i]                route i
///     [0][1]                  summary ("via" label)
///     [0][2] = [m, text]      distance
///     [0][3] = [s, text]      free-flow duration
///     [0][10][0] = [s, text]  duration in traffic
///     [0][10][4][2]           typical range text
///     [3][5][0][k]            traffic span: (level 1 heavy / 2 slow, start m, length m)
///     [1][0][1][g][1][s]      step s of group g:
///       [2][1]                icon class, e.g. "dir-tt dir-tt-turn-left"
///     [1][0][1][g][1][s][0]   step body:
///       [1]                   instruction markup (`<step maneuver='TURN' ...>`)
///       [2] / [3]             distance / duration, as above
///       [7][2] = (_, _, lat, lng)  maneuver location
///       [9][0][1]             hint, e.g. "Pass by X (on the left)"
///       [14]                  instruction as text parts: ((kind, (text, ...)), ...)
///   d[0][7][i]                route i geometry (desktop response only):
///     [0] lat, [1] lng — 1e-7 degree ints, first absolute, then deltas
class DirectionsModel extends DirectionsEntity {
  const DirectionsModel({
    required super.originName,
    required super.destinationName,
    required super.routes,
    super.origin,
    super.destination,
  });

  /// [body] is the raw response text, with or without the `)]}'` guard.
  factory DirectionsModel.fromResponse(String body) {
    final start = body.indexOf('[');
    if (start < 0) {
      throw const FormatException('No JSON array in directions body');
    }
    return DirectionsModel.fromJson(jsonDecode(body.substring(start)) as List);
  }

  factory DirectionsModel.fromJson(List<dynamic> d) {
    final origin = _latLng(_at(d, [0, 0, 0, 0, 0, 2]));
    final destination = _latLng(_at(d, [0, 0, 1, 0, 0, 2]));
    final geometries = _at(d, [0, 7]) as List?;
    final rawRoutes = (_at(d, [0, 1]) as List?) ?? const [];

    final routes = <RouteEntity>[];
    for (var i = 0; i < rawRoutes.length; i++) {
      final route = _parseRoute(
        rawRoutes[i],
        index: i,
        geometry: geometries != null && i < geometries.length
            ? geometries[i]
            : null,
        origin: origin,
        destination: destination,
      );
      if (route != null) routes.add(route);
    }

    return DirectionsModel(
      originName: _at(d, [0, 0, 0, 4]) as String? ?? '',
      destinationName: _at(d, [0, 0, 1, 4]) as String? ?? '',
      origin: origin,
      destination: destination,
      routes: routes,
    );
  }

  static RouteEntity? _parseRoute(
    dynamic r, {
    required int index,
    required dynamic geometry,
    LatLngEntity? origin,
    LatLngEntity? destination,
  }) {
    final distance = _at(r, [0, 2]) as List?;
    final duration = _at(r, [0, 3]) as List?;
    if (distance == null || duration == null) return null;
    final traffic = _at(r, [0, 10, 0]) as List?;

    final steps = <RouteStepEntity>[];
    for (final group in (_at(r, [1, 0, 1]) as List?) ?? const []) {
      for (final raw in (_at(group, [1]) as List?) ?? const []) {
        final step = _parseStep(raw);
        if (step != null) steps.add(step);
      }
    }

    final detailed = _decodeDeltaPolyline(geometry);
    return RouteEntity(
      index: index,
      summary: _at(r, [0, 1]) as String? ?? '',
      distanceMeters: (distance[0] as num).toInt(),
      distanceText: distance[1] as String? ?? '',
      durationSeconds: (duration[0] as num).toInt(),
      durationText: duration[1] as String? ?? '',
      durationInTrafficSeconds: (_at(traffic, [0]) as num?)?.toInt(),
      durationInTrafficText: _at(traffic, [1]) as String?,
      durationRangeText: _at(r, [0, 10, 4, 2]) as String?,
      steps: steps,
      polyline:
          detailed ??
          [?origin, for (final s in steps) ?s.location, ?destination],
      hasDetailedPolyline: detailed != null,
      trafficSpans: [
        for (final span in (_at(r, [3, 5, 0]) as List?) ?? const [])
          ?_parseTrafficSpan(span),
      ],
    );
  }

  static TrafficSpanEntity? _parseTrafficSpan(dynamic span) {
    final level = switch (_at(span, [0])) {
      1 => TrafficLevel.heavy,
      2 => TrafficLevel.slow,
      _ => null,
    };
    final start = _at(span, [1]), length = _at(span, [2]);
    if (level == null || start is! num || length is! num) return null;
    return TrafficSpanEntity(
      level: level,
      startMeters: start.toInt(),
      lengthMeters: length.toInt(),
    );
  }

  static RouteStepEntity? _parseStep(dynamic raw) {
    final s = _at(raw, [0]);
    final iconClass = _at(raw, [2, 1]) as String?;
    final distance = _at(s, [2]) as List?;
    final duration = _at(s, [3]) as List?;
    if (distance == null || duration == null) return null;

    final markup = _at(s, [1]) as String? ?? '';
    final parts = (_at(s, [14]) as List?)
        ?.map((p) => _at(p, [1, 0]))
        .whereType<String>()
        .join();

    return RouteStepEntity(
      instruction: (parts != null && parts.isNotEmpty)
          ? parts
          : markup.replaceAll(RegExp('<[^>]*>'), ''),
      maneuver: RegExp("maneuver='(\\w+)'").firstMatch(markup)?.group(1),
      hint: _at(s, [9, 0, 1]) as String?,
      icon: ManeuverIcon.fromKey(
        RegExp(r'dir-tt-([\w-]+)').firstMatch(iconClass ?? '')?.group(1),
      ),
      distanceMeters: (distance[0] as num).toInt(),
      distanceText: distance[1] as String? ?? '',
      durationSeconds: (duration[0] as num).toInt(),
      location: _latLng(_at(s, [7, 2])),
    );
  }

  /// `[[lat0, dLat1, dLat2, ...], [lng0, dLng1, ...], ...]` in 1e-7 degrees.
  static List<LatLngEntity>? _decodeDeltaPolyline(dynamic g) {
    final lats = _at(g, [0]) as List?;
    final lngs = _at(g, [1]) as List?;
    if (lats == null || lngs == null || lats.isEmpty) return null;
    final points = <LatLngEntity>[];
    var lat = 0, lng = 0;
    for (var i = 0; i < lats.length && i < lngs.length; i++) {
      lat += (lats[i] as num).toInt();
      lng += (lngs[i] as num).toInt();
      points.add(LatLngEntity(lat / 1e7, lng / 1e7));
    }
    return points;
  }

  /// `[_, _, lat, lng]`
  static LatLngEntity? _latLng(dynamic v) {
    final lat = _at(v, [2]), lng = _at(v, [3]);
    return (lat is num && lng is num)
        ? LatLngEntity(lat.toDouble(), lng.toDouble())
        : null;
  }

  /// Null-safe positional lookup.
  static dynamic _at(dynamic node, List<int> path) {
    var cur = node;
    for (final i in path) {
      if (cur is! List || i >= cur.length) return null;
      cur = cur[i];
    }
    return cur;
  }
}
