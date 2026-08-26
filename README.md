# Crop Alerts

Weather-driven early warning for crop diseases, pests and other problems.

The app pulls a ten-day forecast from the Norwegian Meteorological Institute
every six hours, runs it against a set of rules for each crop, and warns you when
conditions start to favour something you would rather avoid — late blight,
Colorado beetle, blossom-end rot. Each warning comes with the readings that
triggered it and what to do about it.

Serbian (Latin) and English. Android and iOS.

## Getting started

```sh
flutter pub get
flutter run
```

Requires Flutter 3.47 or newer.

The app opens on a seeded plot in Belgrade. Add your own from the plots screen
(the pin icon), or edit that one.

## How it works

```
forecast (yr.no)  ─┐
                   ├─→ rule engine ─→ risk per crop, per day ─→ dashboard
crop catalogue    ─┘                                         └─→ notifications
```

**Forecast.** `YrNoWeatherApi` fetches MET Norway's `locationforecast/2.0/compact`
and reduces it to daily minima and maxima for temperature and humidity, plus a
rainfall total. `CachedForecastRepository` keeps one file per plot and refreshes
no more often than every six hours.

**Rules.** A rule is a composable condition tree evaluated against a window of
the forecast. `RuleEngine` scores the rules that match, per threat, and turns the
score into low, moderate or high risk.

**Crops.** A crop has a growing season and a list of threats; each threat has
rules, a description, prevention steps and a response. Out of season, a crop's
rules are not applied at all.

**Alerts.** A background job re-runs the whole pipeline every six hours and
raises a notification when something crosses the level you asked about.

### Where things live

```
lib/
  core/           feature flags, localization, design tokens and theme
  features/
    weather/      yr.no client, parsing, six-hour cache
    rules/        conditions, the engine, scoring, JSON codec
    crops/        crop and threat model, growing seasons, catalogue
    locations/    saved plots
    alerts/       background refresh and notifications
    dashboard/    the pipeline assembled for one screen
  ui/             screens and widgets
  l10n/           translations (app_sr.arb is the template)
assets/
  content/        the crop catalogue, one file per language
  crops/          crop artwork
```

## Adding a crop

Crop content lives in `assets/content/crops_sr.json` and `crops_en.json`. Both
files are produced from a single source so the two languages cannot drift apart:

```sh
python3 tool/generate_crop_catalog.py
```

Edit `tool/generate_crop_catalog.py` and regenerate. Editing the JSON by hand
works too — the tests enforce that the two languages stay structurally identical
either way — but a regeneration will overwrite it.

A crop needs an id, a name, a growing season, and at least one threat:

```json
{
  "id": "krompir",
  "name": "Krompir",
  "season": { "fromMonth": 3, "toMonth": 9 },
  "threats": [ ... ]
}
```

Seasons wrap the turn of the year: garlic planted in October and lifted in June
is `"fromMonth": 10, "toMonth": 6`.

The crop's `id` is also the key for its artwork, in `assets/crops/`. A crop with
no artwork falls back to a seedling rather than rendering nothing.

## Writing a rule

A threat needs at least one rule, or it can never be reported. A rule is an id, a
weight, and a condition:

```json
{
  "id": "krompir.plamenjaca.uslovi-za-infekciju",
  "threatId": "plamenjaca",
  "weight": 2,
  "condition": {
    "type": "allOf",
    "conditions": [
      { "type": "rangeOverlap", "lower": "minTemperature",
        "upper": "maxTemperature", "min": 15, "max": 21 },
      { "type": "metricThreshold", "metric": "minHumidity",
        "comparator": "greaterThan", "value": 65 }
    ]
  }
}
```

### Conditions

| Type | Matches when |
| --- | --- |
| `metricThreshold` | one metric compares against a number |
| `metricBand` | one metric falls inside a range |
| `rangeOverlap` | the day's own range overlaps a range |
| `sumOverDays` | a metric totalled over N days compares against a number |
| `consecutiveDays` | an inner condition holds N days running |
| `allOf`, `anyOf`, `not` | combine other conditions |

Metrics: `minTemperature`, `maxTemperature`, `averageTemperature`,
`minHumidity`, `maxHumidity`, `averageHumidity`, `precipitation`.
Comparators: `lessThan`, `atMost`, `greaterThan`, `atLeast`.

### Choosing between `rangeOverlap` and `metricBand`

This is the distinction worth getting right.

`rangeOverlap` asks whether the day *passed through* a range — the right question
for a pathogen, which only needs a few hours in its favourable window while the
leaf is wet.

`metricBand` on `averageTemperature` asks what kind of day it was — the right
question for insect activity. A 32 °C day whose dawn minimum touched 21 °C is not
a mild day, but `rangeOverlap` on 12–22 °C would match it.

### Weights and scoring

A matching rule contributes its weight to its threat's score. One point is
moderate risk, two are high. So either:

- give a threat two weight-1 rules, where one factor alone is a moderate signal
  and both together are serious; or
- write the decisive combination as a single `allOf` with weight 2.

Prefer the second when the factors genuinely have to occur together. Infection
needs both a temperature window and a wet leaf; either alone is not evidence.

### Rules that fire too readily

A rule that matches almost every day is worse than no rule at all, because it
trains people to ignore the app. Two things to watch:

- **Humidity.** `maxHumidity > 80` is true on most summer nights in the Balkans.
  Key off `minHumidity` instead: it asks whether the leaf ever got a chance to
  dry, which is what actually drives infection.
- **Warmth.** "Warm suits this pest" is true all summer. Make warmth a weight-1
  background signal and let a heat spike or a dry spell be the second.

The end-to-end test in `test/features/crops/catalog_against_real_forecast_test.dart`
runs the catalogue against a captured real forecast and fails if risk comes out
uniform across crops, or if any crop is at high risk on all ten days. Both are
symptoms of a rule keying off something that is always true.

## Localization

UI strings live in `lib/l10n/app_sr.arb` (the template) and `app_en.arb`. Add to
the Serbian file first, then the English one, and regenerate:

```sh
flutter gen-l10n
```

Anything missing a translation is listed in `l10n_untranslated.json`.

Crop and advice text is deliberately *not* in the ARB files. Flutter's generated
localizations are typed getters, so a dynamic key like `crop_paradajz_name`
cannot be looked up at runtime — hence the content assets.

## Feature flags

Toggles for work in progress live in `lib/core/flags/feature_flag.dart` and can
be flipped at runtime from Settings.

| Flag | Default | Gates |
| --- | --- | --- |
| `backgroundAlerts` | on | the six-hourly job and notifications |
| `authentication` | off | signed-in accounts |
| `communityCrops` | off | crops contributed by other growers |
| `remoteRules` | off | rules fetched without shipping a build |
| `mitigationRatings` | off | rating whether advice worked |
| `deviceLocation` | off | GPS instead of typed coordinates |

The flags that are off gate work that has not been built yet. What makes them
cheap is the shape of the code around them, not the boolean: every repository
sits behind an interface, rules and crops round-trip through JSON, and `Crop` and
`Rule` already carry a `source` and an `authorId`.

## Background refresh

The job runs every six hours, refreshes the forecast, re-evaluates, and notifies
when something crosses the level chosen in Settings. Both notification settings
start switched off.

Neither platform guarantees the interval. Android treats six hours as a floor and
may run later; iOS treats it as a hint and decides for itself based on how the
app is used. The app therefore also refreshes when opened, which costs nothing
when a refresh is not due.

Two pieces of native configuration are easy to get wrong and fail silently:

- `ios/Runner/Info.plist` must list the task identifier in
  `BGTaskSchedulerPermittedIdentifiers`, and it must equal
  `BackgroundRefresh.uniqueName`. An unlisted identifier is rejected at
  registration and the task never runs.
- `AndroidManifest.xml` must declare `POST_NOTIFICATIONS`, or Android 13 and
  newer drop every notification.

Both are asserted in `test/features/alerts/native_config_test.dart`.

To trigger a run without waiting, debug builds have a bell in the dashboard app
bar. On Android you can also force the scheduled job:

```sh
adb shell cmd jobscheduler run -f com.cropalert.app 999
```

## Tests

```sh
flutter analyze
flutter test
```

The rule engine, the forecast parser and the caching repository are covered by
unit tests against fixed data, including a captured MET Norway response in
`test/fixtures/`. Screens are covered by widget tests.

## Weather data

Forecasts come from the Norwegian Meteorological Institute under the
[Norwegian Licence for Open Government Data (NLOD) 2.0](https://data.norge.no/nlod/en/2.0)
and [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Their [terms of service](https://api.met.no/doc/TermsOfService) are enforced with
blocks rather than warnings. The client honours them:

- every request identifies the application and a contact address;
- coordinates are capped at four decimals;
- `Last-Modified` is replayed as `If-Modified-Since`;
- the `Expires` header is honoured, ahead of the app's own refresh policy and
  ahead of a user-initiated refresh;
- a 429 backs off rather than retrying.

If you fork this, change the contact address in `YrNoWeatherApi.userAgent`.
Reusing someone else's identifier is a ban-worthy violation of their terms.

Attribution to MET Norway is shown in the app, which their licence requires.

## Third-party assets

- **Inter** — Rasmus Andersson, [SIL Open Font License 1.1](assets/fonts/OFL.txt).
  Bundled rather than fetched, so the app renders correctly on a first launch
  with no signal.
- **Phosphor Icons** — MIT, via the `phosphor_icons` package.
