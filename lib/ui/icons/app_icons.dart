import 'package:phosphor_icons/phosphor_icons.dart';

/// Semantic names for the Phosphor icons the app uses.
///
/// Screens reference these rather than Phosphor directly, so swapping an icon
/// is a one-line change and the icon set stays consistent across the app.
/// Release builds tree-shake the icon font down to only the glyphs listed here.
abstract final class AppIcons {
  // Weather metrics.
  static const PhosphorIconData temperature =
      PhosphorIconsRegular.thermometerSimple;
  static const PhosphorIconData temperatureHigh =
      PhosphorIconsRegular.thermometerHot;
  static const PhosphorIconData temperatureLow =
      PhosphorIconsRegular.thermometerCold;
  static const PhosphorIconData humidity = PhosphorIconsRegular.drop;
  static const PhosphorIconData precipitation = PhosphorIconsRegular.cloudRain;
  static const PhosphorIconData wind = PhosphorIconsRegular.wind;
  static const PhosphorIconData clearSky = PhosphorIconsRegular.sun;

  // Crops and threats.
  static const PhosphorIconData crop = PhosphorIconsRegular.plant;
  static const PhosphorIconData fungalDisease = PhosphorIconsRegular.virus;
  static const PhosphorIconData pest = PhosphorIconsRegular.bug;
  static const PhosphorIconData otherProblem = PhosphorIconsRegular.warning;
  static const PhosphorIconData prevention = PhosphorIconsRegular.shieldCheck;
  static const PhosphorIconData response = PhosphorIconsRegular.sprayBottle;
  static const PhosphorIconData caution = PhosphorIconsRegular.warningOctagon;
  static const PhosphorIconData season = PhosphorIconsRegular.calendarBlank;
  static const PhosphorIconData dormant = PhosphorIconsRegular.moon;

  // Risk states, for use where colour alone should not carry the meaning.
  static const PhosphorIconData riskHigh = PhosphorIconsFill.warningCircle;
  static const PhosphorIconData riskModerate = PhosphorIconsFill.warning;
  static const PhosphorIconData riskLow = PhosphorIconsFill.checkCircle;

  // Places and navigation.
  static const PhosphorIconData location = PhosphorIconsRegular.mapPin;
  static const PhosphorIconData addLocation = PhosphorIconsRegular.mapPinPlus;
  static const PhosphorIconData myLocation = PhosphorIconsRegular.crosshair;
  static const PhosphorIconData chevron = PhosphorIconsRegular.caretRight;
  static const PhosphorIconData reorder = PhosphorIconsRegular.dotsSixVertical;

  // Actions and chrome.
  static const PhosphorIconData refresh = PhosphorIconsRegular.arrowsClockwise;
  static const PhosphorIconData notifications = PhosphorIconsRegular.bell;
  static const PhosphorIconData settings = PhosphorIconsRegular.gear;
  static const PhosphorIconData language = PhosphorIconsRegular.translate;
  static const PhosphorIconData add = PhosphorIconsRegular.plus;
  static const PhosphorIconData edit = PhosphorIconsRegular.pencilSimple;
  static const PhosphorIconData delete = PhosphorIconsRegular.trash;
  static const PhosphorIconData help = PhosphorIconsRegular.question;
  static const PhosphorIconData flags = PhosphorIconsRegular.sliders;

  // States.
  static const PhosphorIconData offline = PhosphorIconsRegular.wifiSlash;
  static const PhosphorIconData lastUpdated = PhosphorIconsRegular.clock;
}
