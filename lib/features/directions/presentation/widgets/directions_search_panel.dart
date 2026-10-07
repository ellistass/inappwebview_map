import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';
import '../bloc/directions_bloc.dart';
import '../bloc/directions_form_cubit.dart';

extension TravelModeIcon on TravelMode {
  IconData get icon => switch (this) {
    TravelMode.driving => Icons.directions_car,
    TravelMode.walking => Icons.directions_walk,
    TravelMode.transit => Icons.directions_transit,
    TravelMode.bicycling => Icons.directions_bike,
  };
}

/// Start/destination form; collapses to a one-line bar after searching.
class DirectionsSearchPanel extends StatefulWidget {
  const DirectionsSearchPanel({super.key});

  @override
  State<DirectionsSearchPanel> createState() => _DirectionsSearchPanelState();
}

class _DirectionsSearchPanelState extends State<DirectionsSearchPanel> {
  late final DirectionsFormCubit _form = context.read<DirectionsFormCubit>();
  late final _originCtrl = TextEditingController(
    text: _form.state.origin.value,
  );
  late final _destCtrl = TextEditingController(
    text: _form.state.destination.value,
  );
  bool _expanded = false;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _search() {
    if (!_form.submit()) return;
    context.unfocus();
    setState(() => _expanded = false);
    context.read<DirectionsBloc>().add(FetchDirectionsEvent(_form.state));
  }

  /// Keeps the text fields in step with the cubit after a swap.
  void _syncControllers(BuildContext _, DirectionsFormState state) {
    if (_originCtrl.text != state.origin.value) {
      _originCtrl.text = state.origin.value;
    }
    if (_destCtrl.text != state.destination.value) {
      _destCtrl.text = state.destination.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DirectionsFormCubit, DirectionsFormState>(
      listenWhen: (p, c) =>
          p.origin != c.origin || p.destination != c.destination,
      listener: _syncControllers,
      child: BlocBuilder<DirectionsFormCubit, DirectionsFormState>(
        builder: (context, state) => AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? _buildPanel(state)
              : _CollapsedBar(
                  state: state,
                  onTap: () => setState(() => _expanded = true),
                ),
        ),
      ),
    );
  }

  Widget _buildPanel(DirectionsFormState state) {
    String? errorFor(PlaceInput input) =>
        state.showErrors && input.isNotValid ? 'Required' : null;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _originCtrl,
                        onChanged: _form.onOriginChanged,
                        // Selecting all makes it easy to type over
                        // "Your location".
                        onTap: () {
                          if (state.originIsCurrentLocation) {
                            _originCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _originCtrl.text.length,
                            );
                          }
                        },
                        style: state.originIsCurrentLocation
                            ? TextStyle(color: context.colorScheme.primary)
                            : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.trip_origin),
                          hintText: 'Start (address or lat,lng)',
                          errorText: errorFor(state.origin),
                          isDense: true,
                          suffixIcon: state.status.isLocating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Use my location',
                                  icon: Icon(
                                    state.originIsCurrentLocation
                                        ? Icons.my_location
                                        : Icons.location_searching,
                                  ),
                                  onPressed: _form.useCurrentLocationAsOrigin,
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _destCtrl,
                        onChanged: _form.onDestinationChanged,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.place),
                          hintText: 'Destination (address or lat,lng)',
                          errorText: errorFor(state.destination),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Swap',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _form.swap,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<TravelMode>(
                    showSelectedIcon: false,
                    segments: [
                      for (final m in TravelMode.values)
                        ButtonSegment(value: m, icon: Icon(m.icon)),
                    ],
                    selected: {state.mode},
                    onSelectionChanged: (s) => _form.onModeChanged(s.first),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _search, child: const Text('Go')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  final DirectionsFormState state;
  final VoidCallback onTap;

  const _CollapsedBar({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      color: context.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(state.mode.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${state.origin.value}  →  ${state.destination.value}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit),
            ],
          ),
        ),
      ),
    );
  }
}
