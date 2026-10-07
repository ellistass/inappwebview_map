import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';

enum PlaceValidationError { empty }

/// An address or "lat,lng" string.
class PlaceInput extends FormzInput<String, PlaceValidationError> {
  const PlaceInput.pure([super.value = '']) : super.pure();
  const PlaceInput.dirty([super.value = '']) : super.dirty();

  @override
  PlaceValidationError? validator(String value) =>
      value.trim().isEmpty ? PlaceValidationError.empty : null;
}

/// Label shown in a field that's pinned to the device's GPS position.
const yourLocationLabel = 'Your location';

enum DirectionsFormStatus {
  editing,
  locating,
  submitted;

  bool get isEditing => this == DirectionsFormStatus.editing;
  bool get isLocating => this == DirectionsFormStatus.locating;
  bool get isSubmitted => this == DirectionsFormStatus.submitted;
}

class DirectionsFormState extends RequestParam {
  final PlaceInput origin;
  final PlaceInput destination;

  /// Set when a field is "Your location": the coordinates sent instead of
  /// the field's text.
  final LatLngEntity? originLocation;
  final LatLngEntity? destinationLocation;

  final TravelMode mode;
  final DirectionsFormStatus status;
  final Failure? failure;

  const DirectionsFormState({
    required this.status,
    this.origin = const PlaceInput.pure(),
    this.destination = const PlaceInput.pure(),
    this.originLocation,
    this.destinationLocation,
    this.mode = TravelMode.driving,
    this.failure,
  });

  factory DirectionsFormState.initial() => const DirectionsFormState(
    status: DirectionsFormStatus.editing,
    origin: PlaceInput.pure('Ikeja, Lagos'),
    destination: PlaceInput.pure('Lekki Phase 1, Lagos'),
  );

  bool get isValid => Formz.validate([origin, destination]);

  /// Only nag about empty fields after the user has tried to search.
  bool get showErrors => status.isSubmitted;

  bool get originIsCurrentLocation => originLocation != null;

  /// Google "Maps URLs" query — no API key needed.
  @override
  Map<String, dynamic> toRequestMap() => {
    'api': '1',
    'origin': _query(origin, originLocation),
    'destination': _query(destination, destinationLocation),
    'travelmode': mode.name,
  };

  static String _query(PlaceInput input, LatLngEntity? pinned) =>
      pinned != null ? '${pinned.lat},${pinned.lng}' : input.value.trim();

  DirectionsFormState copyWith({
    PlaceInput? origin,
    PlaceInput? destination,
    LatLngEntity? originLocation,
    LatLngEntity? destinationLocation,
    bool clearOriginLocation = false,
    bool clearDestinationLocation = false,
    TravelMode? mode,
    DirectionsFormStatus? status,
    Failure? failure,
  }) {
    return DirectionsFormState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      originLocation: clearOriginLocation
          ? null
          : originLocation ?? this.originLocation,
      destinationLocation: clearDestinationLocation
          ? null
          : destinationLocation ?? this.destinationLocation,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      // Cleared unless passed, so the error shows once.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    origin,
    destination,
    originLocation,
    destinationLocation,
    mode,
    status,
    failure,
  ];
}

class DirectionsFormCubit extends Cubit<DirectionsFormState> {
  final GetCurrentLocationUseCase _getCurrentLocation;

  DirectionsFormCubit(this._getCurrentLocation)
    : super(DirectionsFormState.initial());

  // Typing replaces "Your location" with whatever was typed.
  void onOriginChanged(String value) => emit(
    state.copyWith(origin: PlaceInput.dirty(value), clearOriginLocation: true),
  );

  void onDestinationChanged(String value) => emit(
    state.copyWith(
      destination: PlaceInput.dirty(value),
      clearDestinationLocation: true,
    ),
  );

  void onModeChanged(TravelMode mode) => emit(state.copyWith(mode: mode));

  void swap() => emit(
    DirectionsFormState(
      status: state.status,
      mode: state.mode,
      origin: PlaceInput.dirty(state.destination.value),
      destination: PlaceInput.dirty(state.origin.value),
      originLocation: state.destinationLocation,
      destinationLocation: state.originLocation,
    ),
  );

  /// Pins the start to the device's current GPS position.
  Future<void> useCurrentLocationAsOrigin() async {
    if (state.status.isLocating) return;
    final previous = state.status;
    emit(state.copyWith(status: DirectionsFormStatus.locating));
    final result = await _getCurrentLocation();
    result.match(
      (failure) => emit(state.copyWith(status: previous, failure: failure)),
      (location) => emit(
        state.copyWith(
          status: previous,
          origin: const PlaceInput.dirty(yourLocationLabel),
          originLocation: location.position,
        ),
      ),
    );
  }

  /// Marks the form submitted; returns whether it's valid to search.
  bool submit() {
    emit(state.copyWith(status: DirectionsFormStatus.submitted));
    return state.isValid;
  }
}
