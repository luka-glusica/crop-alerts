// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Poljoprivredni Paničar';

  @override
  String get appEyebrow => 'Prognoza rizika za useve';

  @override
  String get appTagline =>
      'Prati vremenske uslove i upozorava kada vašim usevima prete bolesti.';

  @override
  String get riskHigh => 'Visok rizik';

  @override
  String get riskModerate => 'Umeren rizik';

  @override
  String get riskLow => 'Nizak rizik';

  @override
  String get riskOutOfSeason => 'Van sezone';

  @override
  String get conditionsNow => 'Trenutni uslovi';

  @override
  String get temperatureNow => 'Trenutna temperatura';

  @override
  String get temperatureRange24h => 'Min/max (24č)';

  @override
  String get humidityNow => 'Vlažnost vazduha';

  @override
  String get precipitation12h => 'Padavine (12č)';

  @override
  String degreesCelsius(String value) {
    return '$value°C';
  }

  @override
  String percent(String value) {
    return '$value%';
  }

  @override
  String millimetres(String value) {
    return '$value mm';
  }

  @override
  String temperatureRangeValue(String min, String max) {
    return '$min – $max°C';
  }

  @override
  String get today => 'Danas';

  @override
  String get tomorrow => 'Sutra';

  @override
  String lastUpdated(String timestamp) {
    return 'Poslednje ažuriranje: $timestamp';
  }

  @override
  String growingSeason(String from, String to) {
    return 'Sezona: $from – $to';
  }

  @override
  String cropsAtRisk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count useva je ugroženo',
      few: '$count useva su ugrožena',
      one: '$count usev je ugrožen',
      zero: 'Nijedan usev nije ugrožen',
    );
    return '$_temp0';
  }

  @override
  String dormantCrops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count useva van sezone',
      few: '$count useva van sezone',
      one: '$count usev van sezone',
    );
    return '$_temp0';
  }

  @override
  String get threats => 'Pretnje';

  @override
  String get threatFungalDisease => 'Gljivične bolesti';

  @override
  String get threatPest => 'Štetočine';

  @override
  String get threatOther => 'Ostali problemi';

  @override
  String get prevention => 'Prevencija';

  @override
  String get response => 'Mere';

  @override
  String get whyThisRisk => 'Zašto';

  @override
  String get noRiskToday => 'Nema povećanog rizika za ovaj dan.';

  @override
  String get locations => 'Parcele';

  @override
  String get addLocation => 'Dodaj parcelu';

  @override
  String get editLocation => 'Izmeni parcelu';

  @override
  String get locationName => 'Naziv';

  @override
  String get latitude => 'Geografska širina';

  @override
  String get longitude => 'Geografska dužina';

  @override
  String deleteLocationConfirm(String name) {
    return 'Obrisati parcelu „$name“?';
  }

  @override
  String get nameRequired => 'Unesite naziv parcele.';

  @override
  String get invalidLatitude => 'Geografska širina mora biti između -90 i 90.';

  @override
  String get invalidLongitude =>
      'Geografska dužina mora biti između -180 i 180.';

  @override
  String get settings => 'Podešavanja';

  @override
  String get language => 'Jezik';

  @override
  String get languageSystem => 'Kao na uređaju';

  @override
  String get languageSerbian => 'Srpski';

  @override
  String get languageEnglish => 'Engleski';

  @override
  String get notifications => 'Obaveštenja';

  @override
  String get notifyHighRisk => 'Obavesti me o visokom riziku';

  @override
  String get notifyModerateRisk => 'Obavesti me o umerenom riziku';

  @override
  String get developerOptions => 'Razvojne opcije';

  @override
  String get featureFlags => 'Funkcionalnosti';

  @override
  String get resetFeatureFlags => 'Vrati podrazumevano';

  @override
  String get refresh => 'Osveži prognozu';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String get save => 'Sačuvaj';

  @override
  String get cancel => 'Otkaži';

  @override
  String get delete => 'Obriši';

  @override
  String get loading => 'Učitavanje najnovije prognoze…';

  @override
  String get offline => 'Prikazani su sačuvani podaci — nema veze sa mrežom.';

  @override
  String get errorForecastUnavailable =>
      'Nije moguće preuzeti vremensku prognozu.';

  @override
  String get attributionMet =>
      'Podaci: Meteorološki institut Norveške (MET Norway)';

  @override
  String get activePlot => 'Aktivna parcela';

  @override
  String get coordinates => 'Koordinate';

  @override
  String get noPlots => 'Nemate nijednu parcelu.';

  @override
  String get noPlotsHint =>
      'Dodajte parcelu da biste videli prognozu rizika za nju.';

  @override
  String plotDeleted(String name) {
    return 'Parcela „$name“ je obrisana.';
  }

  @override
  String get undo => 'Vrati';

  @override
  String get metricMinTemperature => 'najniža temperatura';

  @override
  String get metricMaxTemperature => 'najviša temperatura';

  @override
  String get metricAverageTemperature => 'prosečna temperatura';

  @override
  String get metricMinHumidity => 'najniža vlažnost';

  @override
  String get metricMaxHumidity => 'najviša vlažnost';

  @override
  String get metricAverageHumidity => 'prosečna vlažnost';

  @override
  String get metricPrecipitation => 'padavine';

  @override
  String observationThreshold(
    String metric,
    String observed,
    String comparison,
    String threshold,
  ) {
    return '$metric $observed $comparison $threshold';
  }

  @override
  String observationBand(
    String metric,
    String observed,
    String min,
    String max,
  ) {
    return '$metric $observed, u opsegu $min – $max';
  }

  @override
  String observationOverDays(
    String metric,
    String observed,
    int days,
    String comparison,
    String threshold,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'za $days dana',
      one: 'za $days dan',
    );
    return '$metric $observed $_temp0 $comparison $threshold';
  }

  @override
  String get outOfSeasonNotice =>
      'Ovaj usev je van sezone, pa se pravila ne primenjuju.';

  @override
  String get allThreats => 'Sve pretnje';

  @override
  String get ratingPrompt => 'Da li je ovaj savet pomogao?';

  @override
  String get ratingHelped => 'Jeste';

  @override
  String get ratingDidNotHelp => 'Nije';

  @override
  String get selectDay => 'Izaberite dan';

  @override
  String alertHighRisk(int count) {
    return 'visok rizik: $count';
  }

  @override
  String alertModerateRisk(int count) {
    return 'umeren rizik: $count';
  }

  @override
  String alertCrops(String names) {
    return 'usevi: $names';
  }

  @override
  String get notificationChannelName => 'Upozorenja o riziku';

  @override
  String get notificationChannelDescription =>
      'Obaveštava kada vremenski uslovi pogoduju bolestima ili štetočinama.';

  @override
  String get refreshNow => 'Osveži odmah';

  @override
  String get about => 'O aplikaciji';

  @override
  String get notificationsDenied =>
      'Obaveštenja su isključena u podešavanjima uređaja.';

  @override
  String get notificationsExplainer =>
      'Provera se pokreće na svakih šest sati i javlja samo kada nešto pređe izabrani nivo.';

  @override
  String get featureFlagsExplainer =>
      'Funkcionalnosti u pripremi. Menjajte samo ako znate šta radite.';
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class AppLocalizationsSrLatn extends AppLocalizationsSr {
  AppLocalizationsSrLatn() : super('sr_Latn');
}
