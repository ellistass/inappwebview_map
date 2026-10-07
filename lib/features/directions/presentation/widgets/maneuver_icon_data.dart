import 'package:flutter/material.dart';

import '../../domain/domain.dart';

extension ManeuverIconData on ManeuverIcon {
  IconData get iconData => switch (this) {
    ManeuverIcon.straight => Icons.straight,
    ManeuverIcon.turnLeft => Icons.turn_left,
    ManeuverIcon.turnRight => Icons.turn_right,
    ManeuverIcon.turnSlightLeft => Icons.turn_slight_left,
    ManeuverIcon.turnSlightRight => Icons.turn_slight_right,
    ManeuverIcon.turnSharpLeft => Icons.turn_sharp_left,
    ManeuverIcon.turnSharpRight => Icons.turn_sharp_right,
    ManeuverIcon.uturnLeft => Icons.u_turn_left,
    ManeuverIcon.uturnRight => Icons.u_turn_right,
    ManeuverIcon.merge => Icons.merge,
    ManeuverIcon.rampLeft => Icons.ramp_left,
    ManeuverIcon.rampRight => Icons.ramp_right,
    ManeuverIcon.forkLeft => Icons.fork_left,
    ManeuverIcon.forkRight => Icons.fork_right,
    ManeuverIcon.roundaboutLeft => Icons.roundabout_left,
    ManeuverIcon.roundaboutRight => Icons.roundabout_right,
    ManeuverIcon.unknown => Icons.navigation,
  };
}

/// "350 m" / "1.2 km", rounded the way turn banners do.
String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
  }
  if (meters >= 100) return '${(meters / 50).round() * 50} m';
  return '${(meters / 10).round() * 10} m';
}

/// "1 hr 5 min" / "12 min".
String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}
