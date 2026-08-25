import 'dart:io';

import 'package:crop_alerts/features/alerts/background_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

/// The background job depends on native configuration that fails silently when
/// it is wrong: iOS rejects an unlisted BGTaskScheduler identifier at
/// registration, and Android refuses to post a notification without the
/// permission declared. Neither produces an error a developer would notice, so
/// they are asserted here.
void main() {
  group('iOS', () {
    late String plist;

    setUpAll(() {
      plist = File('ios/Runner/Info.plist').readAsStringSync();
    });

    test('permits exactly the identifier the Dart side registers', () {
      // workmanager_apple registers the BGTaskScheduler task under the
      // uniqueName passed to registerPeriodicTask, so these must match.
      expect(
        plist,
        contains('<string>${BackgroundRefresh.uniqueName}</string>'),
        reason: 'an identifier missing from BGTaskSchedulerPermittedIdentifiers '
            'is rejected and the task simply never runs',
      );
    });

    test('declares the background modes the task needs', () {
      expect(plist, contains('UIBackgroundModes'));
      expect(plist, contains('<string>fetch</string>'));
      expect(plist, contains('<string>processing</string>'));
    });
  });

  group('Android', () {
    late String manifest;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('declares permission to post notifications', () {
      // Without this, Android 13+ silently drops every notification.
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });

    test('declares permission to restore work after a reboot', () {
      // WorkManager drops scheduled work on restart otherwise, and the job
      // stops without anything going wrong visibly.
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    test('declares internet access', () {
      expect(manifest, contains('android.permission.INTERNET'));
    });
  });

  group('the schedule', () {
    test('runs every six hours', () {
      expect(BackgroundRefresh.interval, const Duration(hours: 6));
    });

    test('clears Android WorkManager\'s fifteen-minute floor', () {
      // Anything shorter would be silently raised to fifteen minutes.
      expect(
        BackgroundRefresh.interval,
        greaterThanOrEqualTo(const Duration(minutes: 15)),
      );
    });
  });
}
