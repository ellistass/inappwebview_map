import 'package:equatable/equatable.dart';

import 'lat_lng_entity.dart';

/// Arrow shown next to a step; mirrors Google's `dir-tt-*` icon classes.
enum ManeuverIcon {
  straight,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  uturnLeft,
  uturnRight,
  merge,
  rampLeft,
  rampRight,
  forkLeft,
  forkRight,
  roundaboutLeft,
  roundaboutRight,
  unknown;

  /// [key] is the class suffix, e.g. `turn-slight-left`.
  static ManeuverIcon fromKey(String? key) => switch (key) {
    'straight' => straight,
    'turn-left' => turnLeft,
    'turn-right' => turnRight,
    'turn-slight-left' => turnSlightLeft,
    'turn-slight-right' => turnSlightRight,
    'turn-sharp-left' => turnSharpLeft,
    'turn-sharp-right' => turnSharpRight,
    'uturn-left' => uturnLeft,
    'uturn-right' => uturnRight,
    'merge' => merge,
    'ramp-left' => rampLeft,
    'ramp-right' => rampRight,
    'fork-left' => forkLeft,
    'fork-right' => forkRight,
    'roundabout-left' => roundaboutLeft,
    'roundabout-right' => roundaboutRight,
    _ => unknown,
  };
}

/// One turn-by-turn instruction.
class RouteStepEntity extends Equatable {
  /// Plain-text instruction, e.g. "Merge onto Expressway1/E1".
  final String instruction;

  /// Secondary line, e.g. "Pass by Abiglow (on the left in 350m)".
  final String? hint;

  /// Google's maneuver code, e.g. DEPART, TURN, MERGE, ROUNDABOUT_ENTER_AND_EXIT.
  /// Only present on some steps — use [icon] for display.
  final String? maneuver;

  final ManeuverIcon icon;

  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;

  /// Where the maneuver happens (start of this step).
  final LatLngEntity? location;

  const RouteStepEntity({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.distanceText = '',
    this.icon = ManeuverIcon.unknown,
    this.hint,
    this.maneuver,
    this.location,
  });

  bool get isDeparture => maneuver == 'DEPART';
  bool get isRoundabout => maneuver?.startsWith('ROUNDABOUT') ?? false;

  RouteStepEntity copyWith({
    String? instruction,
    String? hint,
    String? maneuver,
    ManeuverIcon? icon,
    int? distanceMeters,
    String? distanceText,
    int? durationSeconds,
    LatLngEntity? location,
  }) {
    return RouteStepEntity(
      instruction: instruction ?? this.instruction,
      hint: hint ?? this.hint,
      maneuver: maneuver ?? this.maneuver,
      icon: icon ?? this.icon,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      distanceText: distanceText ?? this.distanceText,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      location: location ?? this.location,
    );
  }

  @override
  List<Object?> get props => [
    instruction,
    hint,
    maneuver,
    icon,
    distanceMeters,
    distanceText,
    durationSeconds,
    location,
  ];
}
