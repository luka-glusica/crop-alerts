import 'package:crop_alerts/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const CropAlertsApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
