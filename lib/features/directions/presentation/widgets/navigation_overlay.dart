import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../bloc/navigation_bloc.dart';
import 'maneuver_icon_data.dart';

const _bannerGreen = Color(0xFF0B6E4F);
const _rerouteGreen = Color(0xFF005F5F);

/// Turn-by-turn chrome over the map: next-maneuver banner, Re-center, and the
/// ETA bar with Exit.
class NavigationOverlay extends StatelessWidget {
  const NavigationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: state.status.isRerouting
                    ? const _MessageBanner('Rerouting…', _rerouteGreen)
                    : state.status.isArrived
                    ? const _MessageBanner('You have arrived', _bannerGreen)
                    : _ManeuverBanner(state: state),
              ),
              const Spacer(),
              if (!state.following && !state.status.isArrived)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _bannerGreen,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => context.read<NavigationBloc>().add(
                        const SetFollowingEvent(true),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Re-center'),
                    ),
                  ),
                ),
              _TripBar(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _ManeuverBanner extends StatelessWidget {
  final NavigationState state;
  const _ManeuverBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final next = state.nextStep;
    final white = context.textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    return Material(
      color: _bannerGreen,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Icon(
                  next?.icon.iconData ?? Icons.flag,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 4),
                Text(
                  formatDistance(state.distanceToNextManeuver),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                next?.instruction ?? 'Arrive at destination',
                style: white,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _MessageBanner(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _TripBar extends StatelessWidget {
  final NavigationState state;
  const _TripBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final arrival = TimeOfDay.fromDateTime(state.arrivalTime).format(context);
    final eta = state.route?.hasTrafficDelay ?? false
        ? Colors.orange.shade800
        : Colors.green.shade700;
    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDuration(state.remainingSeconds),
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: eta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${formatDistance(state.remainingMeters)} · $arrival',
                    style: context.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD93025),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
              ),
              onPressed: () => context.read<NavigationBloc>().add(
                const StopNavigationEvent(),
              ),
              child: const Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }
}
