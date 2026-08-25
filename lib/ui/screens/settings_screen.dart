import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/flags.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/theme.dart';
import '../../features/alerts/alert_providers.dart';
import '../../features/alerts/notification_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/app_card.dart';

/// Language, notifications, and the toggles for what is not finished yet.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s2,
          AppSpacing.s4,
          AppSpacing.s12,
        ),
        children: const [
          _LanguageSection(),
          SizedBox(height: AppSpacing.s6),
          _NotificationsSection(),
          SizedBox(height: AppSpacing.s6),
          _FeatureFlagsSection(),
          SizedBox(height: AppSpacing.s6),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: AppSpacing.s2),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtitle != null) ...[
                Text(subtitle!, style: text.bodySmall),
                const SizedBox(height: AppSpacing.s2),
              ],
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider);

    return _Section(
      title: l10n.language,
      child: RadioGroup<String>(
        // Compared by language code rather than by Locale object, so a saved
        // sr-Latn still matches the Serbian option.
        groupValue: selected?.languageCode ?? 'system',
        onChanged: (value) => ref.read(localeProvider.notifier).setLocale(
              switch (value) {
                'sr' => LocaleController.serbianLatin,
                'en' => LocaleController.english,
                _ => null,
              },
            ),
        child: Column(
          children: [
            for (final option in <(String, String)>[
              (l10n.languageSystem, 'system'),
              (l10n.languageSerbian, 'sr'),
              (l10n.languageEnglish, 'en'),
            ])
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: option.$2,
                title: Text(option.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSection extends ConsumerStatefulWidget {
  const _NotificationsSection();

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection> {
  bool _denied = false;

  /// Asks for permission the moment the grower first opts in, rather than at
  /// launch, so the prompt arrives with some context for what it is for.
  Future<void> _enable(Future<void> Function() apply) async {
    final l10n = AppLocalizations.of(context);
    final granted = await LocalNotificationService(
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDescription,
    ).prepare();

    if (!mounted) return;
    setState(() => _denied = !granted);
    if (granted) await apply();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);

    return _Section(
      title: l10n.notifications,
      subtitle: l10n.notificationsExplainer,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: preferences.high,
            title: Text(l10n.notifyHighRisk),
            onChanged: (enabled) => enabled
                ? _enable(() => controller.setHigh(enabled: true))
                : controller.setHigh(enabled: false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: preferences.moderate,
            title: Text(l10n.notifyModerateRisk),
            onChanged: (enabled) => enabled
                ? _enable(() => controller.setModerate(enabled: true))
                : controller.setModerate(enabled: false),
          ),
          if (_denied)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Row(
                children: [
                  Icon(
                    AppIcons.otherProblem,
                    size: 16,
                    color: context.palette.riskModerate.foreground,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      l10n.notificationsDenied,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureFlagsSection extends ConsumerWidget {
  const _FeatureFlagsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final flags = ref.watch(featureFlagsProvider);
    final controller = ref.read(featureFlagsProvider.notifier);

    return _Section(
      title: l10n.featureFlags,
      subtitle: l10n.featureFlagsExplainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final flag in FeatureFlag.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: flags[flag],
              title: Text(flag.name),
              subtitle: Text(flag.description),
              isThreeLine: true,
              onChanged: (enabled) async {
                await controller.setOverride(flag, enabled);
                // The background job follows this flag, so it has to be told.
                await ref
                    .read(notificationPreferencesProvider.notifier)
                    .syncBackgroundJob();
              },
            ),
          const SizedBox(height: AppSpacing.s2),
          OutlinedButton(
            onPressed: () async {
              await controller.resetAll();
              await ref
                  .read(notificationPreferencesProvider.notifier)
                  .syncBackgroundJob();
            },
            child: Text(l10n.resetFeatureFlags),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return _Section(
      title: l10n.about,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.appTagline, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.s2),
          // Required by the MET Norway terms of service.
          Text(l10n.attributionMet, style: text.bodySmall),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.s2),
            Text('debug build', style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
