import 'package:geolocator/geolocator.dart';

import '../../weather/domain/coordinates.dart';
import '../domain/device_location_service.dart';

/// [DeviceLocationService] backed by the `geolocator` plugin.
class GeolocatorDeviceLocation implements DeviceLocationService {
  /// Long enough for a cold GPS fix outdoors without leaving the grower
  /// staring at a spinner if the device cannot get one at all.
  static const Duration timeLimit = Duration(seconds: 20);

  @override
  Future<DeviceLocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const DeviceLocationResult.failure(
        DeviceLocationFailure.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return const DeviceLocationResult.failure(
          DeviceLocationFailure.permissionDenied,
        );
      case LocationPermission.deniedForever:
        return const DeviceLocationResult.failure(
          DeviceLocationFailure.permissionBlocked,
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
      case LocationPermission.unableToDetermine:
        return const DeviceLocationResult.failure(
          DeviceLocationFailure.unavailable,
        );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: timeLimit),
      );
      return DeviceLocationResult.success(
        Coordinates(latitude: position.latitude, longitude: position.longitude),
      );
    } on Exception {
      // Covers a timed-out fix, a disabled service raced after the check
      // above, and anything else the platform side can throw — all of them
      // mean "no position", not a crash.
      return const DeviceLocationResult.failure(
        DeviceLocationFailure.unavailable,
      );
    }
  }
}
