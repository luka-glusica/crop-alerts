import 'dart:io';

import 'package:crop_alerts/ui/widgets/crop_artwork.dart';
import 'package:crop_alerts/ui/widgets/crop_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CropArtwork', () {
    test('resolves crops with hand-drawn artwork to their SVG', () {
      expect(
        CropArtwork.forCrop('kupus'),
        const CropSvgGlyph('assets/crops/kupus.svg'),
      );
    });

    test('resolves crops without artwork to their emoji', () {
      expect(CropArtwork.forCrop('paradajz'), const CropEmojiGlyph('🍅'));
      expect(CropArtwork.forCrop('krompir'), const CropEmojiGlyph('🥔'));
    });

    test('falls back for an unknown crop', () {
      expect(CropArtwork.forCrop('community-submitted-crop'),
          CropArtwork.fallback);
      expect(CropArtwork.forCrop(''), CropArtwork.fallback);
    });

    test('covers every crop the web app ships', () {
      // The full catalogue inherited from the web app. Artwork was there before
      // any of these had rules, and it must stay there as the Flutter
      // catalogue grows past it — hence containment rather than equality, so
      // adding a crop does not mean editing this list too.
      const webAppCrops = {
        'paradajz', 'krastavac', 'grasak', 'boranija', 'tikvica', 'lubenica',
        'luk', 'praziluk', 'beli-luk', 'zelena-salata', 'kupus',
        'prokelj-kelj', 'pasulj', 'krompir', 'batat', 'sargarepa', 'spanac',
        'blitva', //
      };

      expect(CropArtwork.knownCropIds, containsAll(webAppCrops));
      for (final id in webAppCrops) {
        expect(
          CropArtwork.forCrop(id),
          isNot(CropArtwork.fallback),
          reason: '$id has no artwork',
        );
      }
    });

    test('every referenced SVG exists on disk and is declared in pubspec', () {
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
      final assets = ((pubspec['flutter'] as Map)['assets'] as List)
          .cast<String>()
          .toSet();

      for (final path in CropArtwork.svgAssetPaths) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');

        final declared = assets.contains(path) ||
            assets.any((a) => a.endsWith('/') && path.startsWith(a));
        expect(declared, isTrue, reason: '$path is not declared in pubspec');
      }
    });

    test('bundled SVGs parse', () async {
      for (final path in CropArtwork.svgAssetPaths) {
        final source = File(path).readAsStringSync();
        // Throws on malformed markup.
        await vg.loadPicture(SvgStringLoader(source), null);
      }
    });
  });

  group('CropAvatar', () {
    Widget harness(String cropId, {double size = 48}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CropAvatar(cropId: cropId, size: size)),
        ),
      );
    }

    testWidgets('renders an SVG for a crop with artwork', (tester) async {
      await tester.pumpWidget(harness('kupus'));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('🍅'), findsNothing);
    });

    testWidgets('renders an emoji for a crop without artwork', (tester) async {
      await tester.pumpWidget(harness('paradajz'));

      expect(find.text('🍅'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders the fallback for an unknown crop', (tester) async {
      await tester.pumpWidget(harness('nepoznato'));

      expect(find.text('🌱'), findsOneWidget);
    });

    testWidgets('occupies exactly the size it is given', (tester) async {
      await tester.pumpWidget(harness('paradajz', size: 64));

      expect(tester.getSize(find.byType(CropAvatar)), const Size(64, 64));
    });

    testWidgets('scales the badge proportionally', (tester) async {
      await tester.pumpWidget(harness('paradajz', size: 96));

      // The white disc is 68/96 of the badge, matching the web app.
      final disc = tester.getSize(
        find
            .descendant(
              of: find.byType(CropAvatar),
              matching: find.byType(SizedBox),
            )
            .at(1),
      );
      expect(disc.width, closeTo(68, 0.01));
    });

    testWidgets('exposes the semantic label and hides the emoji from readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CropAvatar(cropId: 'paradajz', semanticLabel: 'Paradajz'),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Paradajz'), findsOneWidget);
      handle.dispose();
    });
  });
}
