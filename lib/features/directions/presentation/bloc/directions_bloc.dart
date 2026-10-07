import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';

enum DirectionsStatus {
  initial,
  loading,
  success,
  failure;

  bool get isInitial => this == DirectionsStatus.initial;
  bool get isLoading => this == DirectionsStatus.loading;
  bool get isSuccess => this == DirectionsStatus.success;
  bool get isFailure => this == DirectionsStatus.failure;
}

// Events
abstract class DirectionsEvent extends Equatable {
  const DirectionsEvent();

  @override
  List<Object?> get props => [];
}

class FetchDirectionsEvent extends DirectionsEvent {
  final RequestParam params;
  const FetchDirectionsEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class SelectRouteEvent extends DirectionsEvent {
  final int index;
  const SelectRouteEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Zoom the map to a step of the selected route (from the steps list).
class FocusStepEvent extends DirectionsEvent {
  final int stepIndex;
  const FocusStepEvent(this.stepIndex);

  @override
  List<Object?> get props => [stepIndex];
}

// State
class DirectionsState extends Equatable {
  final DirectionsStatus status;
  final Failure? failure;
  final DirectionsEntity? data;

  /// The search that produced [data].
  final RequestParam? request;
  final int selectedIndex;

  /// Step of the selected route the map is zoomed to, if any.
  final int? focusedStepIndex;

  const DirectionsState({
    required this.status,
    this.failure,
    this.data,
    this.request,
    this.selectedIndex = 0,
    this.focusedStepIndex,
  });

  factory DirectionsState.initial() =>
      const DirectionsState(status: DirectionsStatus.initial);

  List<RouteEntity> get routes => data?.routes ?? const [];

  RouteEntity? get selectedRoute =>
      selectedIndex < routes.length ? routes[selectedIndex] : null;

  RouteStepEntity? get focusedStep {
    final steps = selectedRoute?.steps ?? const [];
    final i = focusedStepIndex;
    return i != null && i < steps.length ? steps[i] : null;
  }

  /// Every point drawn, for fitting the camera.
  List<LatLngEntity> get allPoints => [for (final r in routes) ...r.polyline];

  DirectionsState copyWith({
    DirectionsStatus? status,
    Failure? failure,
    DirectionsEntity? data,
    RequestParam? request,
    int? selectedIndex,
    int? focusedStepIndex,
  }) {
    return DirectionsState(
      status: status ?? this.status,
      // Cleared unless passed, so a later success doesn't carry an old error.
      failure: failure,
      data: data ?? this.data,
      request: request ?? this.request,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      // Cleared unless passed: any other change returns to the overview.
      focusedStepIndex: focusedStepIndex,
    );
  }

  @override
  List<Object?> get props => [
    status,
    failure,
    data,
    request,
    selectedIndex,
    focusedStepIndex,
  ];
}

// Bloc
class DirectionsBloc extends Bloc<DirectionsEvent, DirectionsState> {
  final GetDirectionsUseCase _getDirections;

  DirectionsBloc(this._getDirections) : super(DirectionsState.initial()) {
    // A new search cancels the one in flight.
    on<FetchDirectionsEvent>(_onFetchDirections, transformer: restartable());
    on<SelectRouteEvent>(_onSelectRoute);
    on<FocusStepEvent>(_onFocusStep);
  }

  Future<void> _onFetchDirections(
    FetchDirectionsEvent event,
    Emitter<DirectionsState> emit,
  ) async {
    emit(state.copyWith(status: DirectionsStatus.loading));
    final result = await _getDirections(event.params);
    result.match(
      (failure) => emit(
        state.copyWith(status: DirectionsStatus.failure, failure: failure),
      ),
      (data) => emit(
        state.copyWith(
          status: DirectionsStatus.success,
          data: data,
          request: event.params,
          selectedIndex: 0,
        ),
      ),
    );
  }

  void _onSelectRoute(SelectRouteEvent event, Emitter<DirectionsState> emit) {
    if (event.index < 0 || event.index >= state.routes.length) return;
    emit(state.copyWith(selectedIndex: event.index));
  }

  void _onFocusStep(FocusStepEvent event, Emitter<DirectionsState> emit) {
    final steps = state.selectedRoute?.steps ?? const [];
    if (event.stepIndex < 0 || event.stepIndex >= steps.length) return;
    emit(state.copyWith(focusedStepIndex: event.stepIndex));
  }
}
