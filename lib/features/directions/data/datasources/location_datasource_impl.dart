import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/user_location_model.dart';
import 'location_datasource.dart';

class LocationDataSourceImpl implements LocationDataSource {
  const LocationDataSourceImpl();

  @override
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationAccessException('Turn on location to navigate');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Location permission is needed to navigate',
      );
    }
  }

  @override
  Future<UserLocationModel> current() async {
    await ensurePermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return UserLocationModel.fromPosition(p);
    } on TimeoutException {
      // Indoors / weak signal: fall back to the last fix if there is one.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return UserLocationModel.fromPosition(last);
      throw const LocationAccessException("Couldn't get your location");
    }
  }

  @override
  Stream<UserLocationModel> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    ).map(UserLocationModel.fromPosition);
  }
}
