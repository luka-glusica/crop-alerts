import 'package:flutter/foundation.dart';

import '../../weather/domain/coordinates.dart';

/// Why the device's position could not be read.
enum DeviceLocationFailure {
  /// The device has location switched off entirely.
  servicesDisabled,

  /// The grower has not granted the permission (yet).
  permissionDenied,

  /// The grower denied it permanently — the only case the app cannot recover
  /// from without a trip to the system settings.
  permissionBlocked,

  /// Permission was granted but a position still could not be produced.
  unavailable,
}

/// The device's position, or why it could not be found.
@immutable
class DeviceLocationResult {
  const DeviceLocationResult.success(this.coordinates) : failure = null;

  const DeviceLocationResult.failure(this.failure) : coordinates = null;

  final Coordinates? coordinates;
  final DeviceLocationFailure? failure;

  bool get isSuccess => coordinates != null;
}

/// Reads the device's current position.
///
/// An interface so the map screen never touches the platform plugin directly —
/// the same shape as the repository and store interfaces elsewhere in this
/// feature area.
abstract class DeviceLocationService {
  Future<DeviceLocationResult> current();
}
