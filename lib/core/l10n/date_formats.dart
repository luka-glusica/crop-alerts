import 'dart:ui';

import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Date formatting for forecast days.
///
/// The formats mirror the web app so the two read the same way: a full weekday
/// with day and month for a forecast row, and a numeric date where space is
/// tight.
class ForecastDateFormats {
  ForecastDateFormats(this.locale, this.l10n);

  /// Builds the formats for the locale currently in effect.
  factory ForecastDateFormats.of(Locale locale, AppLocalizations l10n) {
    return ForecastDateFormats(locale, l10n);
  }

  final Locale locale;
  final AppLocalizations l10n;

  String get _tag => _intlLocale(locale);

  /// `sreda, 27. avgust` — the label for a forecast day.
  String dayLabel(DateTime date, {DateTime? today}) {
    final reference = _dateOnly(today ?? DateTime.now());
    final target = _dateOnly(date);
    final difference = target.difference(reference).inDays;

    if (difference == 0) return l10n.today;
    if (difference == 1) return l10n.tomorrow;

    return DateFormat('EEEE, d. MMMM', _tag).format(date);
  }

  /// `sre` — a three-letter weekday, for the compact ten-day strip.
  String shortWeekday(DateTime date) => DateFormat('E', _tag).format(date);

  /// `27.08.2026.`
  String numericDate(DateTime date) => DateFormat.yMd(_tag).format(date);

  /// `27.08.2026. 14:32` — used for the "last updated" line.
  String timestamp(DateTime dateTime) =>
      DateFormat.yMd(_tag).add_Hm().format(dateTime.toLocal());

  /// The full month name, for growing-season ranges.
  String monthName(int month) =>
      DateFormat.MMMM(_tag).format(DateTime(2024, month));

  /// intl identifies locales with underscores and no `Latn` script data for
  /// Serbian, so `sr-Latn` has to be narrowed to the closest tag intl knows.
  static String _intlLocale(Locale locale) {
    final canonical = Intl.canonicalizedLocale(locale.toLanguageTag());
    return DateFormat.localeExists(canonical)
        ? canonical
        : Intl.canonicalizedLocale(locale.languageCode);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
