import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/theme/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/screens/dashboard_screen.dart';

/// Root of the Crop Alerts application.
class CropAlertsApp extends ConsumerWidget {
  const CropAlertsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Always explicit: the controller has already resolved the device
      // language to one the app ships, or to English.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: LocaleController.supportedLocales,
      home: const DashboardScreen(),
    );
  }
}
