import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ];

  /// Application name, shown in the header and notifications
  ///
  /// In sr, this message translates to:
  /// **'Poljoprivredni Paničar'**
  String get appTitle;

  /// Small uppercase label above the app title
  ///
  /// In sr, this message translates to:
  /// **'Prognoza rizika za useve'**
  String get appEyebrow;

  /// One-sentence description of what the app does
  ///
  /// In sr, this message translates to:
  /// **'Prati vremenske uslove i upozorava kada vašim usevima prete bolesti.'**
  String get appTagline;

  /// No description provided for @riskHigh.
  ///
  /// In sr, this message translates to:
  /// **'Visok rizik'**
  String get riskHigh;

  /// No description provided for @riskModerate.
  ///
  /// In sr, this message translates to:
  /// **'Umeren rizik'**
  String get riskModerate;

  /// No description provided for @riskLow.
  ///
  /// In sr, this message translates to:
  /// **'Nizak rizik'**
  String get riskLow;

  /// Shown for a crop whose growing season has not started or has ended
  ///
  /// In sr, this message translates to:
  /// **'Van sezone'**
  String get riskOutOfSeason;

  /// No description provided for @conditionsNow.
  ///
  /// In sr, this message translates to:
  /// **'Trenutni uslovi'**
  String get conditionsNow;

  /// No description provided for @temperatureNow.
  ///
  /// In sr, this message translates to:
  /// **'Trenutna temperatura'**
  String get temperatureNow;

  /// No description provided for @temperatureRange24h.
  ///
  /// In sr, this message translates to:
  /// **'Min/max (24č)'**
  String get temperatureRange24h;

  /// No description provided for @humidityNow.
  ///
  /// In sr, this message translates to:
  /// **'Vlažnost vazduha'**
  String get humidityNow;

  /// No description provided for @precipitation12h.
  ///
  /// In sr, this message translates to:
  /// **'Padavine (12č)'**
  String get precipitation12h;

  /// No description provided for @degreesCelsius.
  ///
  /// In sr, this message translates to:
  /// **'{value}°C'**
  String degreesCelsius(String value);

  /// No description provided for @percent.
  ///
  /// In sr, this message translates to:
  /// **'{value}%'**
  String percent(String value);

  /// No description provided for @millimetres.
  ///
  /// In sr, this message translates to:
  /// **'{value} mm'**
  String millimetres(String value);

  /// No description provided for @temperatureRangeValue.
  ///
  /// In sr, this message translates to:
  /// **'{min} – {max}°C'**
  String temperatureRangeValue(String min, String max);

  /// No description provided for @today.
  ///
  /// In sr, this message translates to:
  /// **'Danas'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In sr, this message translates to:
  /// **'Sutra'**
  String get tomorrow;

  /// No description provided for @lastUpdated.
  ///
  /// In sr, this message translates to:
  /// **'Poslednje ažuriranje: {timestamp}'**
  String lastUpdated(String timestamp);

  /// Growing season as a month range, e.g. Sezona: mart – oktobar
  ///
  /// In sr, this message translates to:
  /// **'Sezona: {from} – {to}'**
  String growingSeason(String from, String to);

  /// No description provided for @cropsAtRisk.
  ///
  /// In sr, this message translates to:
  /// **'{count, plural, =0{Nijedan usev nije ugrožen} one{{count} usev je ugrožen} few{{count} useva su ugrožena} other{{count} useva je ugroženo}}'**
  String cropsAtRisk(int count);

  /// No description provided for @dormantCrops.
  ///
  /// In sr, this message translates to:
  /// **'{count, plural, one{{count} usev van sezone} few{{count} useva van sezone} other{{count} useva van sezone}}'**
  String dormantCrops(int count);

  /// No description provided for @threats.
  ///
  /// In sr, this message translates to:
  /// **'Pretnje'**
  String get threats;

  /// No description provided for @threatFungalDisease.
  ///
  /// In sr, this message translates to:
  /// **'Gljivične bolesti'**
  String get threatFungalDisease;

  /// No description provided for @threatPest.
  ///
  /// In sr, this message translates to:
  /// **'Štetočine'**
  String get threatPest;

  /// No description provided for @threatOther.
  ///
  /// In sr, this message translates to:
  /// **'Ostali problemi'**
  String get threatOther;

  /// No description provided for @prevention.
  ///
  /// In sr, this message translates to:
  /// **'Prevencija'**
  String get prevention;

  /// Heading for what to do once conditions are already favourable for a threat
  ///
  /// In sr, this message translates to:
  /// **'Mere'**
  String get response;

  /// Heading above the weather conditions that triggered a rule
  ///
  /// In sr, this message translates to:
  /// **'Zašto'**
  String get whyThisRisk;

  /// No description provided for @noRiskToday.
  ///
  /// In sr, this message translates to:
  /// **'Nema povećanog rizika za ovaj dan.'**
  String get noRiskToday;

  /// No description provided for @locations.
  ///
  /// In sr, this message translates to:
  /// **'Parcele'**
  String get locations;

  /// No description provided for @addLocation.
  ///
  /// In sr, this message translates to:
  /// **'Dodaj parcelu'**
  String get addLocation;

  /// No description provided for @editLocation.
  ///
  /// In sr, this message translates to:
  /// **'Izmeni parcelu'**
  String get editLocation;

  /// No description provided for @locationName.
  ///
  /// In sr, this message translates to:
  /// **'Naziv'**
  String get locationName;

  /// No description provided for @latitude.
  ///
  /// In sr, this message translates to:
  /// **'Geografska širina'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In sr, this message translates to:
  /// **'Geografska dužina'**
  String get longitude;

  /// No description provided for @deleteLocationConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati parcelu „{name}“?'**
  String deleteLocationConfirm(String name);

  /// No description provided for @nameRequired.
  ///
  /// In sr, this message translates to:
  /// **'Unesite naziv parcele.'**
  String get nameRequired;

  /// No description provided for @invalidLatitude.
  ///
  /// In sr, this message translates to:
  /// **'Geografska širina mora biti između -90 i 90.'**
  String get invalidLatitude;

  /// No description provided for @invalidLongitude.
  ///
  /// In sr, this message translates to:
  /// **'Geografska dužina mora biti između -180 i 180.'**
  String get invalidLongitude;

  /// No description provided for @settings.
  ///
  /// In sr, this message translates to:
  /// **'Podešavanja'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In sr, this message translates to:
  /// **'Jezik'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In sr, this message translates to:
  /// **'Kao na uređaju'**
  String get languageSystem;

  /// No description provided for @languageSerbian.
  ///
  /// In sr, this message translates to:
  /// **'Srpski'**
  String get languageSerbian;

  /// No description provided for @languageEnglish.
  ///
  /// In sr, this message translates to:
  /// **'Engleski'**
  String get languageEnglish;

  /// No description provided for @notifications.
  ///
  /// In sr, this message translates to:
  /// **'Obaveštenja'**
  String get notifications;

  /// No description provided for @notifyHighRisk.
  ///
  /// In sr, this message translates to:
  /// **'Obavesti me o visokom riziku'**
  String get notifyHighRisk;

  /// No description provided for @notifyModerateRisk.
  ///
  /// In sr, this message translates to:
  /// **'Obavesti me o umerenom riziku'**
  String get notifyModerateRisk;

  /// No description provided for @developerOptions.
  ///
  /// In sr, this message translates to:
  /// **'Razvojne opcije'**
  String get developerOptions;

  /// No description provided for @featureFlags.
  ///
  /// In sr, this message translates to:
  /// **'Funkcionalnosti'**
  String get featureFlags;

  /// No description provided for @resetFeatureFlags.
  ///
  /// In sr, this message translates to:
  /// **'Vrati podrazumevano'**
  String get resetFeatureFlags;

  /// No description provided for @refresh.
  ///
  /// In sr, this message translates to:
  /// **'Osveži prognozu'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In sr, this message translates to:
  /// **'Pokušaj ponovo'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In sr, this message translates to:
  /// **'Sačuvaj'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In sr, this message translates to:
  /// **'Otkaži'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In sr, this message translates to:
  /// **'Obriši'**
  String get delete;

  /// No description provided for @loading.
  ///
  /// In sr, this message translates to:
  /// **'Učitavanje najnovije prognoze…'**
  String get loading;

  /// No description provided for @offline.
  ///
  /// In sr, this message translates to:
  /// **'Prikazani su sačuvani podaci — nema veze sa mrežom.'**
  String get offline;

  /// No description provided for @errorForecastUnavailable.
  ///
  /// In sr, this message translates to:
  /// **'Nije moguće preuzeti vremensku prognozu.'**
  String get errorForecastUnavailable;

  /// Attribution required by the MET Norway API terms of service
  ///
  /// In sr, this message translates to:
  /// **'Podaci: Meteorološki institut Norveške (MET Norway)'**
  String get attributionMet;

  /// No description provided for @activePlot.
  ///
  /// In sr, this message translates to:
  /// **'Aktivna parcela'**
  String get activePlot;

  /// No description provided for @coordinates.
  ///
  /// In sr, this message translates to:
  /// **'Koordinate'**
  String get coordinates;

  /// No description provided for @noPlots.
  ///
  /// In sr, this message translates to:
  /// **'Nemate nijednu parcelu.'**
  String get noPlots;

  /// No description provided for @noPlotsHint.
  ///
  /// In sr, this message translates to:
  /// **'Dodajte parcelu da biste videli prognozu rizika za nju.'**
  String get noPlotsHint;

  /// No description provided for @plotDeleted.
  ///
  /// In sr, this message translates to:
  /// **'Parcela „{name}“ je obrisana.'**
  String plotDeleted(String name);

  /// No description provided for @undo.
  ///
  /// In sr, this message translates to:
  /// **'Vrati'**
  String get undo;

  /// No description provided for @metricMinTemperature.
  ///
  /// In sr, this message translates to:
  /// **'najniža temperatura'**
  String get metricMinTemperature;

  /// No description provided for @metricMaxTemperature.
  ///
  /// In sr, this message translates to:
  /// **'najviša temperatura'**
  String get metricMaxTemperature;

  /// No description provided for @metricAverageTemperature.
  ///
  /// In sr, this message translates to:
  /// **'prosečna temperatura'**
  String get metricAverageTemperature;

  /// No description provided for @metricMinHumidity.
  ///
  /// In sr, this message translates to:
  /// **'najniža vlažnost'**
  String get metricMinHumidity;

  /// No description provided for @metricMaxHumidity.
  ///
  /// In sr, this message translates to:
  /// **'najviša vlažnost'**
  String get metricMaxHumidity;

  /// No description provided for @metricAverageHumidity.
  ///
  /// In sr, this message translates to:
  /// **'prosečna vlažnost'**
  String get metricAverageHumidity;

  /// No description provided for @metricPrecipitation.
  ///
  /// In sr, this message translates to:
  /// **'padavine'**
  String get metricPrecipitation;

  /// No description provided for @observationThreshold.
  ///
  /// In sr, this message translates to:
  /// **'{metric} {observed} {comparison} {threshold}'**
  String observationThreshold(
    String metric,
    String observed,
    String comparison,
    String threshold,
  );

  /// No description provided for @observationBand.
  ///
  /// In sr, this message translates to:
  /// **'{metric} {observed}, u opsegu {min} – {max}'**
  String observationBand(
    String metric,
    String observed,
    String min,
    String max,
  );

  /// No description provided for @observationOverDays.
  ///
  /// In sr, this message translates to:
  /// **'{metric} {observed} {days, plural, one{za {days} dan} other{za {days} dana}} {comparison} {threshold}'**
  String observationOverDays(
    String metric,
    String observed,
    int days,
    String comparison,
    String threshold,
  );

  /// No description provided for @outOfSeasonNotice.
  ///
  /// In sr, this message translates to:
  /// **'Ovaj usev je van sezone, pa se pravila ne primenjuju.'**
  String get outOfSeasonNotice;

  /// No description provided for @allThreats.
  ///
  /// In sr, this message translates to:
  /// **'Sve pretnje'**
  String get allThreats;

  /// No description provided for @ratingPrompt.
  ///
  /// In sr, this message translates to:
  /// **'Da li je ovaj savet pomogao?'**
  String get ratingPrompt;

  /// No description provided for @ratingHelped.
  ///
  /// In sr, this message translates to:
  /// **'Jeste'**
  String get ratingHelped;

  /// No description provided for @ratingDidNotHelp.
  ///
  /// In sr, this message translates to:
  /// **'Nije'**
  String get ratingDidNotHelp;

  /// No description provided for @selectDay.
  ///
  /// In sr, this message translates to:
  /// **'Izaberite dan'**
  String get selectDay;

  /// No description provided for @alertHighRisk.
  ///
  /// In sr, this message translates to:
  /// **'visok rizik: {count}'**
  String alertHighRisk(int count);

  /// No description provided for @alertModerateRisk.
  ///
  /// In sr, this message translates to:
  /// **'umeren rizik: {count}'**
  String alertModerateRisk(int count);

  /// No description provided for @alertCrops.
  ///
  /// In sr, this message translates to:
  /// **'usevi: {names}'**
  String alertCrops(String names);

  /// No description provided for @notificationChannelName.
  ///
  /// In sr, this message translates to:
  /// **'Upozorenja o riziku'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In sr, this message translates to:
  /// **'Obaveštava kada vremenski uslovi pogoduju bolestima ili štetočinama.'**
  String get notificationChannelDescription;

  /// No description provided for @refreshNow.
  ///
  /// In sr, this message translates to:
  /// **'Osveži odmah'**
  String get refreshNow;

  /// No description provided for @about.
  ///
  /// In sr, this message translates to:
  /// **'O aplikaciji'**
  String get about;

  /// No description provided for @notificationsDenied.
  ///
  /// In sr, this message translates to:
  /// **'Obaveštenja su isključena u podešavanjima uređaja.'**
  String get notificationsDenied;

  /// No description provided for @notificationsExplainer.
  ///
  /// In sr, this message translates to:
  /// **'Provera se pokreće na svakih šest sati i javlja samo kada nešto pređe izabrani nivo.'**
  String get notificationsExplainer;

  /// No description provided for @featureFlagsExplainer.
  ///
  /// In sr, this message translates to:
  /// **'Funkcionalnosti u pripremi. Menjajte samo ako znate šta radite.'**
  String get featureFlagsExplainer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsSrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
