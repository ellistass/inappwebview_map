import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/domain.dart';
import '../bloc/directions_bloc.dart';
import '../bloc/navigation_bloc.dart';
import 'map_images.dart';

/// Free OpenFreeMap vector style — no API key.
const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const _lagos = LatLng(6.5244, 3.3792);

// Google Maps' route palette.
const _selectedFill = Color(0xFF1A73E8);
const _selectedCasing = Color(0xFF185ABC);
const _alternativeFill = Color(0xFFA6BCE6);
const _alternativeCasing = Color(0xFF7F97C6);
const _traveledFill = Color(0xFFA0A4A8);
const _traveledCasing = Color(0xFF80868B);
const _slowFill = Color(0xFFF29900);
const _heavyFill = Color(0xFFD93025);

// Follow-camera framing while navigating.
const _navZoom = 17.3;
const _navTilt = 55.0;

/// Aim this far ahead of the arrow so it sits in the lower third, like Google.
const _navLookAheadMeters = 90.0;

extension on LatLngEntity {
  LatLng get toLatLng => LatLng(lat, lng);
  List<double> get coord => [lng, lat];
}

/// Vector map that draws the directions (preview) or the active trip
/// (navigation), and drives the camera for both.
class RouteMap extends StatefulWidget {
  /// Space taken by overlays, so fitted routes aren't hidden under them.
  final EdgeInsets overlayPadding;

  const RouteMap({super.key, this.overlayPadding = EdgeInsets.zero});

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _map;
  bool _styleReady = false;
  final _registeredImages = <String>{};

  // Previous states, so listeners can tell what changed.
  late DirectionsState _lastDirections = _directions;
  late NavigationState _lastNavigation = _navigation;

  DirectionsState get _directions => context.read<DirectionsBloc>().state;
  NavigationState get _navigation => context.read<NavigationBloc>().state;
  double get _dpr => MediaQuery.devicePixelRatioOf(context);

  void _onMapCreated(MapLibreMapController map) {
    _map = map;
    map.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    final map = _map!;
    await _addImage('puck', MapImages.puck(_dpr));
    await _addImage('step-dot', MapImages.stepDot(_dpr));
    await _addImage('origin', MapImages.origin(_dpr));
    await _addImage('destination', MapImages.destinationPin(_dpr));

    const empty = {'type': 'FeatureCollection', 'features': []};
    for (final id in ['routes', 'labels', 'markers', 'puck']) {
      await map.addGeoJsonSource(id, empty);
    }
    await map.addLineLayer(
      'routes',
      'routes-casing',
      const LineLayerProperties(
        lineColor: ['get', 'casing'],
        lineWidth: ['get', 'casingWidth'],
        lineSortKey: ['get', 'z'],
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await map.addLineLayer(
      'routes',
      'routes-fill',
      const LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: ['get', 'width'],
        lineSortKey: ['get', 'z'],
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    await map.addSymbolLayer(
      'markers',
      'markers',
      const SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconAnchor: ['get', 'anchor'],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
    await map.addSymbolLayer(
      'labels',
      'labels',
      const SymbolLayerProperties(
        iconImage: ['get', 'icon'],
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        symbolSortKey: ['get', 'z'],
      ),
    );
    await map.addSymbolLayer(
      'puck',
      'puck',
      const SymbolLayerProperties(
        iconImage: 'puck',
        iconRotate: ['get', 'bearing'],
        iconRotationAlignment: 'map',
        iconPitchAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
    _styleReady = true;
    await _redraw();
    if (_navigation.status.isActive) {
      await _follow(animate: false);
    } else if (_directions.routes.isNotEmpty) {
      await _fitRoutes();
    }
  }

  Future<void> _addImage(String name, Future<dynamic> bytes) async {
    if (_registeredImages.contains(name)) return;
    _registeredImages.add(name);
    await _map!.addImage(name, await bytes);
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng latLng,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (_navigation.status.isActive) return;
    final match = RegExp(r'^(route|label)-(\d+)$').firstMatch(id);
    if (match == null) return;
    context.read<DirectionsBloc>().add(SelectRouteEvent(int.parse(match[2]!)));
  }

  // ── Drawing ────────────────────────────────────────────────────────────

  Future<void> _redraw() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final nav = _navigation;
    final navigating = nav.status.isActive || nav.status.isStarting;

    final routes = <Map<String, dynamic>>[];
    final labels = <Map<String, dynamic>>[];
    final markers = <Map<String, dynamic>>[];
    final puck = <Map<String, dynamic>>[];

    if (navigating && nav.route != null) {
      final route = nav.route!;
      final cum = route.cumulativeMeters;
      final along = nav.alongMeters;
      routes
        ..add(
          _line(
            'traveled',
            route.slice(0, along, cum),
            _traveledFill,
            _traveledCasing,
            1,
            9,
          ),
        )
        ..add(
          _line(
            'route-nav',
            route.slice(along, cum.last, cum),
            _selectedFill,
            _selectedCasing,
            2,
            9,
          ),
        );
      for (final span in route.trafficSpans) {
        if (span.endMeters <= along) continue;
        routes.add(
          _line(
            'traffic-${span.startMeters}',
            route.slice(
              math.max(along, span.startMeters.toDouble()),
              span.endMeters.toDouble(),
              cum,
            ),
            span.level.isHeavy ? _heavyFill : _slowFill,
            null,
            3,
            9,
          ),
        );
      }
      markers.add(
        _point('destination', route.polyline.last, 'destination', 'bottom'),
      );
      if (nav.puck != null) {
        puck.add({
          'type': 'Feature',
          'properties': {'bearing': nav.bearing},
          'geometry': {'type': 'Point', 'coordinates': nav.puck!.coord},
        });
      }
    } else {
      final dir = _directions;
      final selected = dir.selectedIndex;
      for (var i = 0; i < dir.routes.length; i++) {
        final route = dir.routes[i];
        final isSelected = i == selected;
        routes.add(
          _line(
            'route-$i',
            route.polyline,
            isSelected ? _selectedFill : _alternativeFill,
            isSelected ? _selectedCasing : _alternativeCasing,
            isSelected ? 100 : i,
            isSelected ? 7 : 6,
          ),
        );
        if (isSelected) {
          for (final path in route.trafficPaths) {
            routes.add(
              _line(
                'route-$i',
                path.points,
                path.level.isHeavy ? _heavyFill : _slowFill,
                null,
                101,
                7,
              ),
            );
          }
        }
        final at = dir.data?.labelPointFor(i);
        if (at != null) {
          final icon = 'eta|${route.etaText}|${route.distanceText}|$isSelected';
          await _addImage(
            icon,
            MapImages.etaBubble(
              eta: route.etaText,
              distance: route.distanceText,
              selected: isSelected,
              scale: _dpr,
            ),
          );
          labels.add({
            ..._point('label-$i', at, icon, 'bottom'),
            'properties': {'icon': icon, 'z': isSelected ? 1 : 0},
          });
        }
      }
      final route = dir.selectedRoute;
      if (route != null && route.polyline.isNotEmpty) {
        markers
          ..add(_point('origin', route.polyline.first, 'origin', 'center'))
          ..add(
            _point('destination', route.polyline.last, 'destination', 'bottom'),
          );
      }
      final step = dir.focusedStep?.location;
      if (step != null) markers.add(_point('step', step, 'step-dot', 'center'));
    }

    await map.setGeoJsonSource('routes', _collection(routes));
    await map.setGeoJsonSource('labels', _collection(labels));
    await map.setGeoJsonSource('markers', _collection(markers));
    await map.setGeoJsonSource('puck', _collection(puck));
  }

  Map<String, dynamic> _line(
    String id,
    List<LatLngEntity> points,
    Color fill,
    Color? casing,
    num z,
    double width,
  ) {
    return {
      'type': 'Feature',
      'id': id,
      'properties': {
        'color': _hex(fill),
        // No casing on traffic overlays: they sit inside the route's casing.
        'casing': _hex(casing ?? fill),
        'width': width,
        'casingWidth': casing == null ? width : width + 4,
        'z': z,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': [for (final p in points) p.coord],
      },
    };
  }

  Map<String, dynamic> _point(
    String id,
    LatLngEntity at,
    String icon,
    String anchor,
  ) {
    return {
      'type': 'Feature',
      'id': id,
      'properties': {'icon': icon, 'anchor': anchor},
      'geometry': {'type': 'Point', 'coordinates': at.coord},
    };
  }

  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  // ── Camera ─────────────────────────────────────────────────────────────

  Future<void> _fitRoutes() async {
    final points = _directions.allPoints;
    final map = _map;
    if (map == null || points.length < 2) return;
    var s = points.first.lat, n = s, w = points.first.lng, e = w;
    for (final p in points) {
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    // Flatten first so the overview is north-up and untilted.
    await map.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng((s + n) / 2, (w + e) / 2), zoom: 11),
      ),
    );
    final pad = widget.overlayPadding + const EdgeInsets.all(40);
    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
        left: pad.left,
        top: pad.top,
        right: pad.right,
        bottom: pad.bottom,
      ),
    );
  }

  Future<void> _focusStep() async {
    final dir = _directions;
    final route = dir.selectedRoute;
    final i = dir.focusedStepIndex;
    final at = dir.focusedStep?.location;
    if (route == null || i == null || at == null) return;
    await _map?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: at.toLatLng,
          zoom: 17,
          tilt: 45,
          bearing: route.bearingAt(route.stepStartMeters[i].toDouble()),
        ),
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> _follow({bool animate = true}) async {
    final nav = _navigation;
    final puck = nav.puck;
    if (_map == null || puck == null || !nav.following) return;
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: puck.offset(nav.bearing, _navLookAheadMeters).toLatLng,
        zoom: _navZoom,
        tilt: _navTilt,
        bearing: nav.bearing,
      ),
    );
    if (animate) {
      await _map!.animateCamera(
        update,
        duration: const Duration(milliseconds: 1000),
      );
    } else {
      await _map!.moveCamera(update);
    }
  }

  // ── State changes ──────────────────────────────────────────────────────

  void _onDirectionsChanged(DirectionsState previous, DirectionsState current) {
    if (_navigation.status.isActive) return;
    _redraw();
    if (current.status.isSuccess && previous.data != current.data) {
      _fitRoutes();
    } else if (current.focusedStepIndex != null &&
        current.focusedStepIndex != previous.focusedStepIndex) {
      _focusStep();
    }
  }

  void _onNavigationChanged(NavigationState previous, NavigationState current) {
    final wasActive = previous.status.isActive || previous.status.isStarting;
    final isActive = current.status.isActive || current.status.isStarting;
    _redraw();
    if (wasActive && !isActive) {
      _fitRoutes();
    } else if (isActive) {
      _follow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DirectionsBloc, DirectionsState>(
          listenWhen: (p, c) =>
              p.data != c.data ||
              p.selectedIndex != c.selectedIndex ||
              p.focusedStepIndex != c.focusedStepIndex,
          listener: (_, state) {
            _onDirectionsChanged(_lastDirections, state);
            _lastDirections = state;
          },
        ),
        BlocListener<NavigationBloc, NavigationState>(
          listener: (_, state) {
            _onNavigationChanged(_lastNavigation, state);
            _lastNavigation = state;
          },
        ),
      ],
      child: Listener(
        // Any touch while following hands the camera to the user; the
        // Re-center button gives it back.
        onPointerDown: (_) {
          final nav = _navigation;
          if (nav.status.isActive && nav.following) {
            context.read<NavigationBloc>().add(const SetFollowingEvent(false));
          }
        },
        child: MapLibreMap(
          styleString: _styleUrl,
          initialCameraPosition: const CameraPosition(target: _lagos, zoom: 11),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          compassEnabled: false,
          trackCameraPosition: true,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        ),
      ),
    );
  }
}
