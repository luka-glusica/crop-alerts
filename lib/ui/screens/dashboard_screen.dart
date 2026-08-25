import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/l10n/date_formats.dart';
import '../../core/theme/theme.dart';
import '../../features/alerts/background_refresh.dart';
import '../../features/crops/domain/crop_assessment.dart';
import '../../features/dashboard/dashboard.dart';
import '../../features/weather/domain/weather_failure.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/app_card.dart';
import '../widgets/crop_risk_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/risk_badge.dart';
import 'crop_detail_screen.dart';
import 'locations_screen.dart';

/// The app's home: what the weather is about to do to the active plot's crops.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final dashboard = ref.watch(dashboardProvider(locale));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.s4,
        title: Row(
          children: [
            SvgPicture.asset('assets/logo.svg', width: 32, height: 32),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          // Waiting six hours to find out whether the background job works is
          // not a workable development loop.
          if (kDebugMode)
            IconButton(
              icon: const Icon(AppIcons.notifications),
              tooltip: 'Run background check now',
              onPressed: () async {
                final outcome = await BackgroundRefresh.runOnce();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Background run: ${outcome.name}')),
                );
              },
            ),
          IconButton(
            icon: const Icon(AppIcons.location),
            tooltip: l10n.locations,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LocationsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshDashboard(ref, locale),
        child: dashboard.when(
          loading: () => _Message(icon: AppIcons.refresh, text: l10n.loading),
          error: (error, stack) => _ErrorState(
            failure: error is WeatherFailure ? error : null,
            onRetry: () => ref.invalidate(dashboardProvider(locale)),
          ),
          data: (data) => data == null
              ? _Message(icon: AppIcons.location, text: l10n.noPlots)
              : _DashboardBody(dashboard: data),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final formats = ForecastDateFormats.of(Localizations.localeOf(context), l10n);
    final now = dashboard.forecast.now;

    return ListView(
      // Always scrollable, so pull-to-refresh works even when the content fits.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s12,
      ),
      children: [
        _PlotHeader(dashboard: dashboard),
        if (dashboard.isStale) ...[
          const SizedBox(height: AppSpacing.s3),
          _StaleBanner(failure: dashboard.failure),
        ],
        const SizedBox(height: AppSpacing.s4),

        Text(l10n.conditionsNow.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: AppSpacing.s2),
        // Rows of Expanded tiles rather than a GridView: a grid needs a fixed
        // aspect ratio, and "Trenutna temperatura" wraps to two lines on a
        // narrow screen, which pushed the reading out of the tile.
        _MetricRow(
          children: [
            MetricTile(
              icon: AppIcons.temperature,
              label: l10n.temperatureNow,
              value: l10n.degreesCelsius(_oneDecimal(now.temperature)),
            ),
            MetricTile(
              icon: AppIcons.temperatureHigh,
              label: l10n.temperatureRange24h,
              value: l10n.temperatureRangeValue(
                _oneDecimal(now.minTemperature24h),
                _oneDecimal(now.maxTemperature24h),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        _MetricRow(
          children: [
            MetricTile(
              icon: AppIcons.humidity,
              label: l10n.humidityNow,
              value: l10n.percent(_oneDecimal(now.humidity)),
            ),
            MetricTile(
              icon: AppIcons.precipitation,
              label: l10n.precipitation12h,
              value: l10n.millimetres(_oneDecimal(now.precipitation12h)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),

        Row(
          children: [
            Expanded(
              child: Text(l10n.cropsAtRisk(dashboard.atRiskCount),
                  style: text.titleSmall),
            ),
            if (dashboard.atRiskCount > 0) RiskBadge(level: dashboard.worst),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        for (final assessment in dashboard.growing) ...[
          CropRiskCard(
            assessment: assessment,
            formats: formats,
            onTap: () => _openCrop(context, assessment),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],

        if (dashboard.dormant.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          _DormantSection(dormant: dashboard.dormant, formats: formats),
        ],

        const SizedBox(height: AppSpacing.s6),
        Row(
          children: [
            Icon(AppIcons.lastUpdated, size: 14, color: palette.textMuted),
            const SizedBox(width: AppSpacing.s1),
            Expanded(
              child: Text(
                l10n.lastUpdated(formats.timestamp(dashboard.forecast.updatedAt)),
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        // Required by the MET Norway terms of service.
        Text(l10n.attributionMet, style: text.bodySmall),
      ],
    );
  }

  static String _oneDecimal(double value) => value.toStringAsFixed(1);

  static void _openCrop(BuildContext context, CropAssessment assessment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CropDetailScreen(assessment: assessment),
      ),
    );
  }
}

/// Two metric tiles side by side, matched in height by their content.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s2),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _PlotHeader extends StatelessWidget {
  const _PlotHeader({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final coordinates = dashboard.location.coordinates;

    return AppCard(
      color: context.palette.surfaceMuted,
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          const Icon(AppIcons.location, size: 20),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.activePlot.toUpperCase(), style: text.labelSmall),
                Text(dashboard.location.name, style: text.titleSmall),
                Text(
                  '${coordinates.latitudeParam}, ${coordinates.longitudeParam}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({this.failure});

  final WeatherFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.palette.riskModerate;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.xlAll,
      ),
      child: Row(
        children: [
          Icon(AppIcons.offline, size: 18, color: colors.foreground),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              l10n.offline,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Out-of-season crops, collapsed.
///
/// They are kept on the screen rather than hidden — a grower should be able to
/// see the app knows about them — but folded away, since they have nothing to
/// report until their season comes round.
class _DormantSection extends StatelessWidget {
  const _DormantSection({required this.dormant, required this.formats});

  final List<CropAssessment> dormant;
  final ForecastDateFormats formats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: AppSpacing.s2),
        leading: Icon(AppIcons.dormant, color: palette.textMuted),
        title: Text(
          l10n.dormantCrops(dormant.length),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        children: [
          for (final assessment in dormant) ...[
            CropRiskCard(
              assessment: assessment,
              formats: formats,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      CropDetailScreen(assessment: assessment),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
        Icon(icon, size: 40, color: palette.textMuted),
        const SizedBox(height: AppSpacing.s3),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, this.failure});

  final WeatherFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s6),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        Icon(
          failure is WeatherNetworkFailure ? AppIcons.offline : AppIcons.otherProblem,
          size: 40,
          color: palette.riskHigh.accent,
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          l10n.errorForecastUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ),
      ],
    );
  }
}
