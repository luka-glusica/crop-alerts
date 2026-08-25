import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/theme.dart';
import 'ui/screens/style_gallery_screen.dart';

/// Root of the Crop Alerts application.
///
/// Localization and the real screens arrive in later steps; for now the home
/// screen is the design-token gallery so the theme can be reviewed on device.
class CropAlertsApp extends StatelessWidget {
  const CropAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Alerts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: kDebugMode
          ? const StyleGalleryScreen()
          : const Scaffold(body: Center(child: Text('Crop Alerts'))),
    );
  }
}
