import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';

enum NavigationStatus {
  idle,
  starting,
  navigating,
  rerouting,
  arrived,
  failure;

  bool get isIdle => this == NavigationStatus.idle;
  bool get isStarting => this == NavigationStatus.starting;
  bool get isNavigating => this == NavigationStatus.navigating;
  bool get isRerouting => this == NavigationStatus.rerouting;
  bool get isArrived => this == NavigationStatus.arrived;
  bool get isFailure => this == NavigationStatus.failure;

  /// Turn-by-turn UI is on screen.
  bool get isActive => isNavigating || isRerouting || isArrived;
}

// Events
abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

class StartNavigationEvent extends NavigationEvent {
  final RouteEntity route;

  /// The search that produced [route]; reused (with a new origin) to reroute.
  final RequestParam request;

  const StartNavigationEvent({required this.route, required this.request});

  @override
  List<Object?> get props => [route, request];
}

class StopNavigationEvent extends NavigationEvent {
  const StopNavigationEvent();
}

/// The user panned the map (false) or tapped Re-center (true).
class SetFollowingEvent extends NavigationEvent {
  final bool following;
  const SetFollowingEvent(this.following);

  @override
  List<Object?> get props => [following];
}

class _LocationUpdatedEvent extends NavigationEvent {
  final UserLocationEntity location;
  const _LocationUpdatedEvent(this.location);

  @override
  List<Object?> get props => [location];
}

/// Same search, starting from where the user is now.
class _RerouteParam extends RequestParam {
  final RequestParam base;
  final LatLngEntity origin;

  const _RerouteParam(this.base, this.origin);

  @override
  Map<String, dynamic> toRequestMap() => {
    ...base.toRequestMap(),
    'origin': '${origin.lat},${origin.lng}',
  };

  @override
  List<Object?> get props => [base, origin];
}

// State
class NavigationState extends Equatable {
  final NavigationStatus status;
  final Failure? failure;
  final RouteEntity? route;
  final RequestParam? request;

  /// Raw GPS fix.
  final UserLocationEntity? location;

  /// [location] projected onto the route.
  final LatLngEntity? snapped;
  final double alongMeters;
  final double offsetMeters;

  /// Direction of travel, degrees clockwise from north.
  final double bearing;

  final int stepIndex;

  /// Camera tracks the user; false after they pan away.
  final bool following;

  const NavigationState({
    required this.status,
    this.failure,
    this.route,
    this.request,
    this.location,
    this.snapped,
    this.alongMeters = 0,
    this.offsetMeters = 0,
    this.bearing = 0,
    this.stepIndex = 0,
    this.following = true,
  });

  factory NavigationState.initial() =>
      const NavigationState(status: NavigationStatus.idle);

  /// Where to draw the arrow: on the road when on route, raw GPS otherwise.
  LatLngEntity? get puck => status.isRerouting
      ? location?.position ?? snapped
      : snapped ?? location?.position;

  /// The maneuver coming up (the start of the next step), or null on the
  /// last stretch before arriving.
  RouteStepEntity? get nextStep {
    final steps = route?.steps ?? const [];
    return stepIndex + 1 < steps.length ? steps[stepIndex + 1] : null;
  }

  /// Metres until [nextStep] — or until the destination on the last step.
  double get distanceToNextManeuver {
    final r = route;
    if (r == null) return 0;
    final starts = r.stepStartMeters;
    final target = stepIndex + 1 < starts.length
        ? starts[stepIndex + 1].toDouble()
        : r.distanceMeters.toDouble();
    return (target - alongMeters).clamp(0, double.infinity);
  }

  double get remainingMeters => route == null
      ? 0
      : (route!.distanceMeters - alongMeters).clamp(0, double.infinity);

  int get remainingSeconds => route?.remainingSecondsAt(alongMeters) ?? 0;

  DateTime get arrivalTime =>
      DateTime.now().add(Duration(seconds: remainingSeconds));

  NavigationState copyWith({
    NavigationStatus? status,
    Failure? failure,
    RouteEntity? route,
    RequestParam? request,
    UserLocationEntity? location,
    LatLngEntity? snapped,
    double? alongMeters,
    double? offsetMeters,
    double? bearing,
    int? stepIndex,
    bool? following,
  }) {
    return NavigationState(
      status: status ?? this.status,
      // Cleared unless passed, so a later update doesn't carry an old error.
      failure: failure,
      route: route ?? this.route,
      request: request ?? this.request,
      location: location ?? this.location,
      snapped: snapped ?? this.snapped,
      alongMeters: alongMeters ?? this.alongMeters,
      offsetMeters: offsetMeters ?? this.offsetMeters,
      bearing: bearing ?? this.bearing,
      stepIndex: stepIndex ?? this.stepIndex,
      following: following ?? this.following,
    );
  }

  @override
  List<Object?> get props => [
    status,
    failure,
    route,
    request,
    location,
    snapped,
    alongMeters,
    offsetMeters,
    bearing,
    stepIndex,
    following,
  ];
}

// Bloc
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  /// Further than this from the route counts as off-route…
  static const offRouteMeters = 40.0;

  /// …for this many fixes in a row before rerouting (GPS jitters).
  static const offRouteFixes = 3;

  /// Within this of the destination counts as arrived.
  static const arrivalMeters = 25.0;

  final EnsureLocationPermissionUseCase _ensurePermission;
  final WatchLocationUseCase _watchLocation;
  final GetDirectionsUseCase _getDirections;

  StreamSubscription<UserLocationEntity>? _locationSub;
  int _offRouteCount = 0;

  NavigationBloc(
    this._ensurePermission,
    this._watchLocation,
    this._getDirections,
  ) : super(NavigationState.initial()) {
    on<StartNavigationEvent>(_onStart, transformer: restartable());
    on<StopNavigationEvent>(_onStop);
    on<SetFollowingEvent>(_onSetFollowing);
    // Fixes that arrive while a reroute is in flight are stale — drop them.
    on<_LocationUpdatedEvent>(_onLocationUpdated, transformer: droppable());
  }

  Future<void> _onStart(
    StartNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    await _locationSub?.cancel();
    _offRouteCount = 0;
    emit(
      NavigationState(
        status: NavigationStatus.starting,
        route: event.route,
        request: event.request,
        snapped: event.route.polyline.firstOrNull,
        bearing: event.route.bearingAt(0),
      ),
    );

    final permission = await _ensurePermission();
    if (permission.isLeft()) {
      emit(
        state.copyWith(
          status: NavigationStatus.failure,
          failure: permission.getLeft().toNullable(),
        ),
      );
      return;
    }

    emit(state.copyWith(status: NavigationStatus.navigating));
    _locationSub = _watchLocation().listen(
      (location) => add(_LocationUpdatedEvent(location)),
    );
  }

  Future<void> _onStop(
    StopNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    await _locationSub?.cancel();
    _locationSub = null;
    emit(NavigationState.initial());
  }

  void _onSetFollowing(SetFollowingEvent event, Emitter<NavigationState> emit) {
    if (state.following == event.following) return;
    emit(state.copyWith(following: event.following));
  }

  Future<void> _onLocationUpdated(
    _LocationUpdatedEvent event,
    Emitter<NavigationState> emit,
  ) async {
    final route = state.route;
    if (route == null || route.polyline.length < 2) return;
    if (!(state.status.isNavigating || state.status.isRerouting)) return;

    final location = event.location;
    final fix = route.locate(location.position, hintMeters: state.alongMeters);
    final offRoute =
        fix.offsetMeters > offRouteMeters.clamp(location.accuracy, 100);
    _offRouteCount = offRoute ? _offRouteCount + 1 : 0;

    if (_offRouteCount >= offRouteFixes) {
      await _reroute(location, emit);
      return;
    }

    final arrived = route.distanceMeters - fix.alongMeters < arrivalMeters;
    emit(
      state.copyWith(
        status: arrived
            ? NavigationStatus.arrived
            : NavigationStatus.navigating,
        location: location,
        snapped: fix.snapped,
        // Never slide backwards on a jittery fix.
        alongMeters: fix.alongMeters < state.alongMeters - 30
            ? state.alongMeters
            : fix.alongMeters,
        offsetMeters: fix.offsetMeters,
        bearing: offRoute && location.isMoving && location.heading != null
            ? location.heading
            : route.bearingAt(fix.alongMeters),
        stepIndex: route.stepIndexAt(fix.alongMeters),
      ),
    );
    if (arrived) await _locationSub?.cancel();
  }

  Future<void> _reroute(
    UserLocationEntity location,
    Emitter<NavigationState> emit,
  ) async {
    final request = state.request;
    if (request == null) return;
    emit(
      state.copyWith(
        status: NavigationStatus.rerouting,
        location: location,
        bearing: location.heading,
      ),
    );

    final result = await _getDirections(
      _RerouteParam(request, location.position),
    );
    _offRouteCount = 0;
    result.match(
      // Keep going on the old route; the next off-route streak retries.
      (failure) => emit(
        state.copyWith(status: NavigationStatus.navigating, failure: failure),
      ),
      (directions) {
        final route = directions.primary!;
        emit(
          state.copyWith(
            status: NavigationStatus.navigating,
            route: route,
            snapped: route.polyline.first,
            alongMeters: 0,
            offsetMeters: 0,
            bearing: route.bearingAt(0),
            stepIndex: 0,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _locationSub?.cancel();
    return super.close();
  }
}
