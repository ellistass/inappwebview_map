import 'package:equatable/equatable.dart';

enum TrafficLevel {
  slow,
  heavy;

  bool get isSlow => this == TrafficLevel.slow;
  bool get isHeavy => this == TrafficLevel.heavy;
}

/// A stretch of the route with slower-than-normal traffic, measured in
/// metres along the route from its start.
class TrafficSpanEntity extends Equatable {
  final TrafficLevel level;
  final int startMeters;
  final int lengthMeters;

  const TrafficSpanEntity({
    required this.level,
    required this.startMeters,
    required this.lengthMeters,
  });

  int get endMeters => startMeters + lengthMeters;

  TrafficSpanEntity copyWith({
    TrafficLevel? level,
    int? startMeters,
    int? lengthMeters,
  }) {
    return TrafficSpanEntity(
      level: level ?? this.level,
      startMeters: startMeters ?? this.startMeters,
      lengthMeters: lengthMeters ?? this.lengthMeters,
    );
  }

  @override
  List<Object?> get props => [level, startMeters, lengthMeters];
}
