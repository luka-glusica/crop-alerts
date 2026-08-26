import 'package:crop_alerts/core/l10n/date_formats.dart';
import 'package:crop_alerts/core/l10n/locale_controller.dart';
import 'package:crop_alerts/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Loads the real delegates, which is what initialises intl's date symbols
  /// for a locale — formatting silently falls back to English without it.
  Future<ForecastDateFormats> formatsFor(WidgetTester tester, Locale locale) async {
    late ForecastDateFormats formats;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleController.supportedLocales,
        home: Builder(
          builder: (context) {
            formats = ForecastDateFormats.of(
              Localizations.localeOf(context),
              AppLocalizations.of(context),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return formats;
  }

  final wednesday = DateTime(2026, 8, 26, 12);

  group('ForecastDateFormats in Serbian', () {
    testWidgets('names the weekday and month in Serbian', (tester) async {
      final formats = await formatsFor(tester, LocaleController.serbianLatin);

      final label = formats.dayLabel(wednesday, today: DateTime(2026, 8, 20));
      expect(label, contains('avgust'));
      expect(label, contains('26'));
      // Latin script, not Cyrillic.
      expect(label, isNot(matches(RegExp('[Ѐ-ӿ]'))));
    });

    testWidgets('uses the localized today and tomorrow labels', (tester) async {
      final formats = await formatsFor(tester, LocaleController.serbianLatin);

      expect(formats.dayLabel(wednesday, today: wednesday), 'Danas');
      expect(
        formats.dayLabel(wednesday, today: DateTime(2026, 8, 25)),
        'Sutra',
      );
    });

    testWidgets('ignores the time of day when comparing dates', (tester) async {
      final formats = await formatsFor(tester, LocaleController.serbianLatin);

      expect(
        formats.dayLabel(DateTime(2026, 8, 26, 23, 59),
            today: DateTime(2026, 8, 26, 0, 1)),
        'Danas',
      );
    });

    testWidgets('names months for growing seasons', (tester) async {
      final formats = await formatsFor(tester, LocaleController.serbianLatin);

      expect(formats.monthName(3), 'mart');
      expect(formats.monthName(10), 'oktobar');
    });
  });

  group('ForecastDateFormats in English', () {
    testWidgets('falls back to English names', (tester) async {
      final formats = await formatsFor(tester, LocaleController.english);

      final label = formats.dayLabel(wednesday, today: DateTime(2026, 8, 20));
      expect(label, contains('August'));
      expect(formats.dayLabel(wednesday, today: wednesday), 'Today');
      expect(formats.monthName(3), 'March');
    });
  });
}
