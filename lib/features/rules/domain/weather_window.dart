import '../../weather/domain/daily_forecast.dart';
import 'weather_metric.dart';

/// A view of the forecast centred on one day.
///
/// Conditions are evaluated against a window rather than a bare day so that
/// multi-day rules — three consecutive humid days, 15 mm of rain over a week —
/// can look forward without the engine having to pass the whole forecast around
/// and track offsets itself.
class WeatherWindow {
  const WeatherWindow({required this.days, required this.index})
      : assert(index >= 0, 'index must be within the forecast');

  /// The whole forecast, in chronological order.
  final List<DailyForecast> days;

  /// Position of the day being evaluated.
  final int index;

  /// The day being evaluated.
  DailyForecast get day => days[index];

  /// The calendar date being evaluated.
  DateTime get date => day.date;

  /// How many days remain from here to the end of the forecast, inclusive.
  int get remaining => days.length - index;

  /// Reads [metric] for the day being evaluated.
  double read(WeatherMetric metric) => metric.read(day);

  /// The next [count] days starting with this one.
  ///
  /// Returns fewer than [count] when the forecast runs out, so a rule asking
  /// for three days near the end of the range is evaluated against what exists
  /// rather than against invented data.
  List<DailyForecast> forward(int count) {
    final end = (index + count).clamp(index, days.length);
    return days.sublist(index, end);
  }

  /// A window on the day [offset] days after this one, or `null` past the end.
  WeatherWindow? shifted(int offset) {
    final target = index + offset;
    if (target < 0 || target >= days.length) return null;
    return WeatherWindow(days: days, index: target);
  }

  /// Builds a window for every day of [forecast].
  static List<WeatherWindow> over(List<DailyForecast> forecast) {
    return [
      for (var i = 0; i < forecast.length; i++)
        WeatherWindow(days: forecast, index: i),
    ];
  }
}
