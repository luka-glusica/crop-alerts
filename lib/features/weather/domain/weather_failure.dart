/// Why a forecast request did not produce data.
///
/// These are deliberately coarse: the UI only ever needs to distinguish
/// "you are offline" from "something is wrong at their end", and the caching
/// repository only needs to know whether retrying immediately is pointless.
sealed class WeatherFailure implements Exception {
  const WeatherFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never reached the server: no connectivity, DNS, or a timeout.
class WeatherNetworkFailure extends WeatherFailure {
  const WeatherNetworkFailure(super.message);
}

/// MET Norway asked us to slow down.
///
/// Their terms require backing off immediately rather than retrying, so this is
/// kept distinct from an ordinary server error.
class WeatherRateLimitedFailure extends WeatherFailure {
  const WeatherRateLimitedFailure(super.message, {this.retryAfter});

  /// Parsed from the `Retry-After` header when present.
  final Duration? retryAfter;
}

/// The request was rejected or the server failed.
class WeatherServerFailure extends WeatherFailure {
  const WeatherServerFailure(super.message, {required this.statusCode});

  final int statusCode;
}

/// A response arrived but could not be understood.
class WeatherFormatFailure extends WeatherFailure {
  const WeatherFormatFailure(super.message);
}
