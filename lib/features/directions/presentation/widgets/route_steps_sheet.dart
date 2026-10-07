import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/core.dart';
import '../../domain/domain.dart';
import '../bloc/directions_bloc.dart';
import 'maneuver_icon_data.dart';

/// Turn-by-turn list for the selected route. Tapping a step zooms the map to
/// it and closes the sheet.
class RouteStepsSheet extends StatelessWidget {
  const RouteStepsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<DirectionsBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const RouteStepsSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectionsBloc, DirectionsState>(
      buildWhen: (p, c) => p.selectedRoute != c.selectedRoute,
      builder: (context, state) {
        final route = state.selectedRoute;
        if (route == null) return const SizedBox.shrink();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView.separated(
            controller: controller,
            itemCount: route.steps.length + 1,
            separatorBuilder: (_, i) => i == 0
                ? const Divider(height: 1)
                : const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => i == 0
                ? _Header(route: route)
                : _StepTile(
                    step: route.steps[i - 1],
                    onTap: () {
                      context.read<DirectionsBloc>().add(FocusStepEvent(i - 1));
                      Navigator.of(context).pop();
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final RouteEntity route;
  const _Header({required this.route});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: route.etaText,
                  style: TextStyle(
                    color: route.hasTrafficDelay
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: '  (${route.distanceText})'),
              ],
            ),
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('via ${route.summary}', style: context.textTheme.bodyMedium),
          if (route.durationRangeText != null)
            Text(
              'Typically ${route.durationRangeText}',
              style: context.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final RouteStepEntity step;
  final VoidCallback onTap;

  const _StepTile({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: SizedBox(width: 40, child: Icon(step.icon.iconData, size: 28)),
      title: Text(step.instruction),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.hint != null) Text(step.hint!),
          Text(step.distanceText, style: context.textTheme.labelSmall),
        ],
      ),
    );
  }
}
