import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/core.dart';
import '../bloc/directions_bloc.dart';
import '../bloc/directions_form_cubit.dart';
import '../bloc/navigation_bloc.dart';
import '../widgets/directions_search_panel.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/route_map.dart';
import '../widgets/route_options_bar.dart';

class DirectionsPage extends StatelessWidget {
  const DirectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GetIt.instance<DirectionsFormCubit>()),
        BlocProvider(
          create: (_) =>
              GetIt.instance<DirectionsBloc>()
                ..add(FetchDirectionsEvent(DirectionsFormState.initial())),
        ),
        BlocProvider(create: (_) => GetIt.instance<NavigationBloc>()),
      ],
      child: const _DirectionsView(),
    );
  }
}

class _DirectionsView extends StatelessWidget {
  const _DirectionsView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DirectionsBloc, DirectionsState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: (context, state) {
            if (state.status.isFailure) {
              context.showErrorSnackbar(state.failure!.message);
            }
          },
        ),
        BlocListener<DirectionsFormCubit, DirectionsFormState>(
          listenWhen: (p, c) => c.failure != null && p.failure != c.failure,
          listener: (context, state) =>
              context.showErrorSnackbar(state.failure!.message),
        ),
        BlocListener<NavigationBloc, NavigationState>(
          listenWhen: (p, c) => c.failure != null && p.failure != c.failure,
          listener: (context, state) =>
              context.showErrorSnackbar(state.failure!.message),
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            const RouteMap(
              overlayPadding: EdgeInsets.only(
                top: 72,
                bottom: RouteOptionsBar.height + 24,
              ),
            ),
            BlocBuilder<NavigationBloc, NavigationState>(
              buildWhen: (p, c) => p.status.isActive != c.status.isActive,
              builder: (context, nav) => nav.status.isActive
                  ? const NavigationOverlay()
                  : const _PreviewOverlay(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search panel on top, route cards at the bottom.
class _PreviewOverlay extends StatelessWidget {
  const _PreviewOverlay();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: DirectionsSearchPanel(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: RouteOptionsBar(),
            ),
          ),
        ),
      ],
    );
  }
}
