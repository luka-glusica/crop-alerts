import 'dart:convert';
import 'dart:io';

import 'package:crop_alerts/features/rules/data/condition_codec.dart';
import 'package:crop_alerts/features/rules/domain/rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The README teaches people how to write a rule. If its example stops being
/// valid, the documentation is worse than none.
void main() {
  late String readme;

  setUpAll(() {
    readme = File('README.md').readAsStringSync();
  });

  test('the example rule parses', () {
    final match = RegExp(
      r'```json\n(\{\n  "id": "krompir\.plamenjaca[\s\S]*?\n\})\n```',
    ).firstMatch(readme);
    expect(match, isNotNull, reason: 'the example rule is no longer in README.md');

    final rule = ConditionCodec.ruleFromJson(
      jsonDecode(match!.group(1)!) as Map<String, dynamic>,
    );

    expect(rule.threatId, 'plamenjaca');
    expect(rule.weight, 2);
    expect(rule.source, RuleSource.builtIn);
  });

  test('every condition type is documented', () {
    final codec =
        File('lib/features/rules/data/condition_codec.dart').readAsStringSync();
    final types = RegExp(r"^      '([a-zA-Z]+)' =>", multiLine: true)
        .allMatches(codec)
        .map((m) => m.group(1)!);

    for (final type in types) {
      expect(readme, contains('`$type`'), reason: '$type is undocumented');
    }
  });

  test('the adb command names the real application id', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final applicationId =
        RegExp(r'applicationId = "([^"]+)"').firstMatch(gradle)!.group(1)!;

    expect(readme, contains(applicationId));
  });
}
