import 'package:flutter/foundation.dart';

/// The months of the year a crop is in the ground.
///
/// Ranges wrap: garlic planted in October and lifted in June is
/// `GrowingSeason(fromMonth: 10, toMonth: 6)`, which covers October through
/// June rather than nothing at all. Outside the season a crop is dormant and
/// its rules are not evaluated — warning someone about late blight in January
/// is noise that teaches them to ignore the app.
@immutable
class GrowingSeason {
  const GrowingSeason({required this.fromMonth, required this.toMonth})
      : assert(fromMonth >= 1 && fromMonth <= 12, 'fromMonth must be 1–12'),
        assert(toMonth >= 1 && toMonth <= 12, 'toMonth must be 1–12');

  /// A crop that is never out of season, such as something under glass.
  static const GrowingSeason yearRound =
      GrowingSeason(fromMonth: 1, toMonth: 12);

  /// First month of the season, 1–12.
  final int fromMonth;

  /// Last month of the season, inclusive, 1–12.
  final int toMonth;

  /// Whether the season runs across the turn of the year.
  bool get wrapsYear => fromMonth > toMonth;

  /// Whether [month] falls inside the season.
  bool contains(int month) {
    if (month < 1 || month > 12) return false;
    if (wrapsYear) return month >= fromMonth || month <= toMonth;
    return month >= fromMonth && month <= toMonth;
  }

  /// Whether [date] falls inside the season.
  bool containsDate(DateTime date) => contains(date.month);

  /// Every month of the season, in the order they occur.
  List<int> get months {
    if (!wrapsYear) {
      return [for (var m = fromMonth; m <= toMonth; m++) m];
    }
    return [
      for (var m = fromMonth; m <= 12; m++) m,
      for (var m = 1; m <= toMonth; m++) m,
    ];
  }

  /// How many months the season covers.
  int get length => months.length;

  Map<String, dynamic> toJson() => {
        'fromMonth': fromMonth,
        'toMonth': toMonth,
      };

  @override
  bool operator ==(Object other) =>
      other is GrowingSeason &&
      other.fromMonth == fromMonth &&
      other.toMonth == toMonth;

  @override
  int get hashCode => Object.hash(fromMonth, toMonth);

  @override
  String toString() => 'GrowingSeason($fromMonth–$toMonth)';
}
