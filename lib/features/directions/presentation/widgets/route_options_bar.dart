import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';
import '../bloc/directions_bloc.dart';
import '../bloc/navigation_bloc.dart';
import 'route_steps_sheet.dart';

/// Bottom strip: one card per route (recommended + alternatives).
class RouteOptionsBar extends StatelessWidget {
  static const height = 168.0;

  const RouteOptionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectionsBloc, DirectionsState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.data != c.data ||
          p.selectedIndex != c.selectedIndex,
      builder: (context, state) {
        if (state.status.isLoading) return const _LoadingCard();
        if (state.routes.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: state.routes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _RouteCard(
              route: state.routes[i],
              selected: i == state.selectedIndex,
              onTap: () =>
                  context.read<DirectionsBloc>().add(SelectRouteEvent(i)),
              onSteps: () {
                context.read<DirectionsBloc>().add(SelectRouteEvent(i));
                RouteStepsSheet.show(context);
              },
              onStart: () => context.read<NavigationBloc>().add(
                StartNavigationEvent(
                  route: state.routes[i],
                  request: state.request!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteEntity route;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSteps;
  final VoidCallback onStart;

  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
    required this.onSteps,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final etaColor = route.hasTrafficDelay
        ? Colors.orange.shade800
        : Colors.green.shade700;
    return SizedBox(
      width: 250,
      child: Card(
        elevation: selected ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? context.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      route.etaText,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: etaColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      route.distanceText,
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'via ${route.summary}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall,
                ),
                Text(
                  route.isAlternative ? 'Alternative' : 'Best route',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Start'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onSteps,
                      icon: const Icon(Icons.format_list_bulleted, size: 18),
                      label: const Text('Steps'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Finding routes…'),
            ],
          ),
        ),
      ),
    );
  }
}
