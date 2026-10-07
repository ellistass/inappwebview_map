import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inappwebview_map/features/directions/data/data.dart';
import 'package:inappwebview_map/features/directions/domain/domain.dart';

void main() {
  DirectionsModel load(String name) => DirectionsModel.fromResponse(
    File('test/fixtures/$name').readAsStringSync(),
  );

  group('desktop response', () {
    final d = load('directions_desktop.txt');

    test('waypoints', () {
      expect(d.originName, 'Ikeja, Lagos');
      expect(d.destinationName, 'Lekki Phase 1, Lagos');
      expect(d.origin, isNotNull);
      expect(d.destination, isNotNull);
    });

    test('primary route + alternatives', () {
      expect(d.routes, hasLength(3));
      final p = d.primary!;
      expect(p.summary, 'Expressway1/E1');
      expect(p.distanceMeters, 31956);
      expect(p.durationSeconds, 2505);
      expect(p.durationInTrafficSeconds, isNotNull);
      expect(p.durationRangeText, contains(' to '));
      expect(d.alternatives.map((r) => r.distanceMeters), [34212, 35152]);
      expect(d.alternatives.every((r) => r.isAlternative), isTrue);
    });

    test('steps', () {
      final steps = d.primary!.steps;
      expect(steps.first.maneuver, 'DEPART');
      expect(
        steps.any(
          (s) =>
              s.instruction ==
              'Merge onto Expressway1/Lagos - Ibadan Express Rd/Lagos - Ibadan Expy/Lagos - Ojoo Expy/E1',
        ),
        isTrue,
      );
      expect(steps.every((s) => s.location != null), isTrue);
      // Step distances add up to the route distance (within rounding).
      final sum = steps.fold<int>(0, (a, s) => a + s.distanceMeters);
      expect((sum - d.primary!.distanceMeters).abs(), lessThan(50));
    });

    test('detailed polyline spans origin → destination', () {
      for (final r in d.routes) {
        expect(r.hasDetailedPolyline, isTrue);
        expect(r.polyline.length, greaterThan(1000));
        expect(r.polyline.last.lat, closeTo(d.destination!.lat, 1e-3));
        expect(r.polyline.last.lng, closeTo(d.destination!.lng, 1e-3));
      }
    });
  });

  group('desktop extras', () {
    final d = load('directions_desktop.txt');
    final r = d.primary!;

    test('step icons, hints, distance text', () {
      expect(r.steps.every((s) => s.icon != ManeuverIcon.unknown), isTrue);
      expect(r.steps[1].icon, ManeuverIcon.turnLeft);
      expect(
        r.steps.any((s) => s.hint?.startsWith('Pass by') ?? false),
        isTrue,
      );
      expect(r.steps.first.distanceText, isNotEmpty);
    });

    test('traffic spans', () {
      expect(r.trafficSpans, [
        const TrafficSpanEntity(
          level: TrafficLevel.slow,
          startMeters: 25302,
          lengthMeters: 642,
        ),
        const TrafficSpanEntity(
          level: TrafficLevel.heavy,
          startMeters: 26090,
          lengthMeters: 533,
        ),
        const TrafficSpanEntity(
          level: TrafficLevel.slow,
          startMeters: 29643,
          lengthMeters: 1003,
        ),
      ]);
      final paths = r.trafficPaths;
      expect(paths, hasLength(3));
      // Each slice's length matches its span.
      for (var i = 0; i < paths.length; i++) {
        final pts = paths[i].points;
        var len = 0.0;
        for (var k = 1; k < pts.length; k++) {
          len += pts[k - 1].distanceTo(pts[k]);
        }
        expect(len, closeTo(r.trafficSpans[i].lengthMeters, 5));
      }
    });

    test('locate snaps a nearby point and reports progress', () {
      final cum = r.cumulativeMeters;
      final onRoute = r.pointAt(10000, cum);
      // Nudge ~30 m north.
      final off = LatLngEntity(onRoute.lat + 0.00027, onRoute.lng);
      final fix = r.locate(off);
      expect(fix.alongMeters, closeTo(10000, 60));
      expect(fix.offsetMeters, inInclusiveRange(1, 35));
      expect(r.locate(onRoute, hintMeters: 9900).offsetMeters, lessThan(1));
    });

    test('step index and bearing', () {
      expect(r.stepIndexAt(0), 0);
      final merge = r.steps.indexWhere((s) => s.maneuver == 'MERGE');
      expect(r.stepIndexAt(r.stepStartMeters[merge] + 1.0), merge);
      final b = r.bearingAt(15000);
      expect(b, inInclusiveRange(0, 360));
      expect(
        r.remainingSecondsAt(r.distanceMeters / 2),
        closeTo(r.etaSeconds / 2, 2),
      );
    });

    test('label points differ per route', () {
      final labels = [
        for (var i = 0; i < d.routes.length; i++) d.labelPointFor(i),
      ];
      expect(labels.toSet(), hasLength(d.routes.length));
    });
  });

  group('lite response', () {
    final d = load('directions_lite.txt');

    test('routes parse, polyline falls back to maneuver points', () {
      expect(d.routes, hasLength(2));
      expect(d.primary!.summary, 'Expressway1/E1');
      expect(d.alternatives.single.summary, 'A1');
      final r = d.primary!;
      expect(r.hasDetailedPolyline, isFalse);
      expect(r.polyline.first, d.origin);
      expect(r.polyline.last, d.destination);
      expect(r.polyline.length, r.steps.length + 2);
    });
  });

  test('throws on non-JSON body', () {
    expect(() => DirectionsModel.fromResponse('nope'), throwsFormatException);
  });
}
