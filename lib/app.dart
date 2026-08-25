import 'package:flutter/material.dart';

/// Root of the Crop Alerts application.
///
/// Theme, localization and routing are wired up in later steps; for now this is
/// a deliberately empty shell so the project builds and runs end to end.
class CropAlertsApp extends StatelessWidget {
  const CropAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Crop Alerts',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Crop Alerts')),
      ),
    );
  }
}
