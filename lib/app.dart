import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/theme/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/screens/style_gallery_screen.dart';

/// Root of the Crop Alerts application.
///
/// The real screens arrive in later steps; for now the home screen is the
/// design-token gallery so the theme and localizations can be reviewed on
/// device.
class CropAlertsApp extends ConsumerWidget {
  const CropAlertsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // `null` follows the device, which then resolves against
      // supportedLocales; Serbian is listed first so it wins for any device
      // language the app does not translate.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: LocaleController.supportedLocales,
      home: kDebugMode
          ? const StyleGalleryScreen()
          : const Scaffold(body: Center(child: Text('Crop Alerts'))),
    );
  }
}
