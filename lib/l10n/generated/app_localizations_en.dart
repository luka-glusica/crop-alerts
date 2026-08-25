// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Crop Alerts';

  @override
  String get appEyebrow => 'Crop risk forecast';

  @override
  String get appTagline =>
      'Watches the weather and warns you when your crops are at risk of disease.';

  @override
  String get riskHigh => 'High risk';

  @override
  String get riskModerate => 'Moderate risk';

  @override
  String get riskLow => 'Low risk';

  @override
  String get riskOutOfSeason => 'Out of season';

  @override
  String get conditionsNow => 'Current conditions';

  @override
  String get temperatureNow => 'Temperature now';

  @override
  String get temperatureRange24h => 'Min/max (24h)';

  @override
  String get humidityNow => 'Humidity';

  @override
  String get precipitation12h => 'Rainfall (12h)';

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
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String lastUpdated(String timestamp) {
    return 'Last updated: $timestamp';
  }

  @override
  String growingSeason(String from, String to) {
    return 'Season: $from – $to';
  }

  @override
  String cropsAtRisk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count crops at risk',
      one: '$count crop at risk',
      zero: 'No crops at risk',
    );
    return '$_temp0';
  }

  @override
  String dormantCrops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count crops out of season',
      one: '$count crop out of season',
    );
    return '$_temp0';
  }

  @override
  String get threats => 'Threats';

  @override
  String get threatFungalDisease => 'Fungal diseases';

  @override
  String get threatPest => 'Pests';

  @override
  String get threatOther => 'Other problems';

  @override
  String get prevention => 'Prevention';

  @override
  String get response => 'What to do';

  @override
  String get whyThisRisk => 'Why';

  @override
  String get noRiskToday => 'No raised risk for this day.';

  @override
  String get locations => 'Plots';

  @override
  String get addLocation => 'Add plot';

  @override
  String get editLocation => 'Edit plot';

  @override
  String get locationName => 'Name';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String deleteLocationConfirm(String name) {
    return 'Delete the plot “$name”?';
  }

  @override
  String get nameRequired => 'Enter a name for the plot.';

  @override
  String get invalidLatitude => 'Latitude must be between -90 and 90.';

  @override
  String get invalidLongitude => 'Longitude must be between -180 and 180.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Match device';

  @override
  String get languageSerbian => 'Serbian';

  @override
  String get languageEnglish => 'English';

  @override
  String get notifications => 'Notifications';

  @override
  String get notifyHighRisk => 'Notify me about high risk';

  @override
  String get notifyModerateRisk => 'Notify me about moderate risk';

  @override
  String get developerOptions => 'Developer options';

  @override
  String get featureFlags => 'Features';

  @override
  String get resetFeatureFlags => 'Restore defaults';

  @override
  String get refresh => 'Refresh forecast';

  @override
  String get retry => 'Try again';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get loading => 'Loading the latest forecast…';

  @override
  String get offline => 'Showing saved data — no network connection.';

  @override
  String get errorForecastUnavailable =>
      'Could not fetch the weather forecast.';

  @override
  String get attributionMet =>
      'Data: Norwegian Meteorological Institute (MET Norway)';

  @override
  String get activePlot => 'Active plot';

  @override
  String get coordinates => 'Coordinates';

  @override
  String get noPlots => 'You have no plots yet.';

  @override
  String get noPlotsHint => 'Add a plot to see its risk forecast.';

  @override
  String plotDeleted(String name) {
    return 'Plot “$name” deleted.';
  }

  @override
  String get undo => 'Undo';

  @override
  String get metricMinTemperature => 'minimum temperature';

  @override
  String get metricMaxTemperature => 'maximum temperature';

  @override
  String get metricAverageTemperature => 'average temperature';

  @override
  String get metricMinHumidity => 'minimum humidity';

  @override
  String get metricMaxHumidity => 'maximum humidity';

  @override
  String get metricAverageHumidity => 'average humidity';

  @override
  String get metricPrecipitation => 'rainfall';

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
    return '$metric $observed, within $min – $max';
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
      other: 'over $days days',
      one: 'over $days day',
    );
    return '$metric $observed $_temp0 $comparison $threshold';
  }

  @override
  String get outOfSeasonNotice =>
      'This crop is out of season, so its rules do not apply.';

  @override
  String get allThreats => 'All threats';

  @override
  String get ratingPrompt => 'Did this advice help?';

  @override
  String get ratingHelped => 'Yes';

  @override
  String get ratingDidNotHelp => 'No';

  @override
  String get selectDay => 'Choose a day';

  @override
  String alertHighRisk(int count) {
    return 'high risk: $count';
  }

  @override
  String alertModerateRisk(int count) {
    return 'moderate risk: $count';
  }

  @override
  String alertCrops(String names) {
    return 'crops: $names';
  }

  @override
  String get notificationChannelName => 'Risk alerts';

  @override
  String get notificationChannelDescription =>
      'Warns when the weather favours a disease or a pest.';

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get about => 'About';

  @override
  String get notificationsDenied =>
      'Notifications are switched off in the device settings.';

  @override
  String get notificationsExplainer =>
      'The check runs every six hours and only speaks up when something crosses the level you pick.';

  @override
  String get featureFlagsExplainer =>
      'Work in progress. Change these only if you know what they do.';
}
