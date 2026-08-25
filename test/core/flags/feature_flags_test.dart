import 'package:crop_alerts/core/flags/flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlag', () {
    test('background alerts ship on, future features ship off', () {
      expect(FeatureFlag.backgroundAlerts.defaultValue, isTrue);
      expect(FeatureFlag.authentication.defaultValue, isFalse);
      expect(FeatureFlag.communityCrops.defaultValue, isFalse);
      expect(FeatureFlag.remoteRules.defaultValue, isFalse);
      expect(FeatureFlag.mitigationRatings.defaultValue, isFalse);
      expect(FeatureFlag.deviceLocation.defaultValue, isFalse);
    });

    test('storage keys are namespaced and unique', () {
      final keys = FeatureFlag.values.map((f) => f.storageKey).toSet();
      expect(keys, hasLength(FeatureFlag.values.length));
      expect(keys.every((k) => k.startsWith('feature_flag.')), isTrue);
    });

    test('byName resolves known flags and tolerates removed ones', () {
      expect(FeatureFlag.byName('backgroundAlerts'), FeatureFlag.backgroundAlerts);
      expect(FeatureFlag.byName('flagThatWasDeleted'), isNull);
    });
  });

  group('FeatureFlags', () {
    test('falls back to defaults when nothing is overridden', () {
      const flags = FeatureFlags.defaults();
      for (final flag in FeatureFlag.values) {
        expect(flags[flag], flag.defaultValue, reason: flag.name);
        expect(flags.isOverridden(flag), isFalse);
      }
    });

    test('an override wins over the default', () {
      const flags = FeatureFlags.defaults();
      final on = flags.withOverride(FeatureFlag.authentication, true);

      expect(on[FeatureFlag.authentication], isTrue);
      expect(on.isOverridden(FeatureFlag.authentication), isTrue);
      // Untouched flags are unaffected.
      expect(on[FeatureFlag.communityCrops], isFalse);
    });

    test('overriding to the default value still counts as an override', () {
      final flags = const FeatureFlags.defaults()
          .withOverride(FeatureFlag.backgroundAlerts, true);

      expect(flags[FeatureFlag.backgroundAlerts], isTrue);
      expect(flags.isOverridden(FeatureFlag.backgroundAlerts), isTrue);
    });

    test('a null override clears back to the default', () {
      final off = const FeatureFlags.defaults()
          .withOverride(FeatureFlag.backgroundAlerts, false);
      final cleared = off.withOverride(FeatureFlag.backgroundAlerts, null);

      expect(off[FeatureFlag.backgroundAlerts], isFalse);
      expect(cleared[FeatureFlag.backgroundAlerts], isTrue);
      expect(cleared.isOverridden(FeatureFlag.backgroundAlerts), isFalse);
    });

    test('withOverride does not mutate the receiver', () {
      const original = FeatureFlags.defaults();
      original.withOverride(FeatureFlag.authentication, true);

      expect(original[FeatureFlag.authentication], isFalse);
    });

    test('value equality', () {
      final a = const FeatureFlags.defaults()
          .withOverride(FeatureFlag.authentication, true);
      final b = const FeatureFlags.defaults()
          .withOverride(FeatureFlag.authentication, true);
      final c = const FeatureFlags.defaults()
          .withOverride(FeatureFlag.authentication, false);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('InMemoryFeatureFlagStore', () {
    test('round-trips overrides', () async {
      final store = InMemoryFeatureFlagStore();
      await store.writeOverride(FeatureFlag.remoteRules, true);

      expect(store.readOverrides(), {FeatureFlag.remoteRules: true});

      await store.writeOverride(FeatureFlag.remoteRules, null);
      expect(store.readOverrides(), isEmpty);
    });

    test('clear removes everything', () async {
      final store = InMemoryFeatureFlagStore({
        FeatureFlag.remoteRules: true,
        FeatureFlag.authentication: true,
      });

      await store.clear();
      expect(store.readOverrides(), isEmpty);
    });

    test('readOverrides returns a copy', () {
      final store = InMemoryFeatureFlagStore({FeatureFlag.remoteRules: true});
      store.readOverrides().clear();

      expect(store.readOverrides(), hasLength(1));
    });
  });

  group('featureFlagsProvider', () {
    ProviderContainer containerWith(FeatureFlagStore store) {
      final container = ProviderContainer(
        overrides: [featureFlagStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('throws a helpful error when the store is not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod wraps provider build errors in its own (non-exported)
      // exception type, so assert on the message rather than the class.
      expect(
        () => container.read(featureFlagsProvider),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('must be overridden in ProviderScope'),
            'reports that featureFlagStoreProvider needs an override',
          ),
        ),
      );
    });

    test('reads persisted overrides at startup', () {
      final container = containerWith(
        InMemoryFeatureFlagStore({FeatureFlag.backgroundAlerts: false}),
      );

      expect(
        container.read(featureFlagsProvider)[FeatureFlag.backgroundAlerts],
        isFalse,
      );
    });

    test('setOverride updates state and persists', () async {
      final store = InMemoryFeatureFlagStore();
      final container = containerWith(store);

      await container
          .read(featureFlagsProvider.notifier)
          .setOverride(FeatureFlag.mitigationRatings, true);

      expect(
        container.read(featureFlagsProvider)[FeatureFlag.mitigationRatings],
        isTrue,
      );
      expect(store.readOverrides(), {FeatureFlag.mitigationRatings: true});
    });

    test('toggle flips the effective value', () async {
      final container = containerWith(InMemoryFeatureFlagStore());
      final notifier = container.read(featureFlagsProvider.notifier);

      await notifier.toggle(FeatureFlag.backgroundAlerts);
      expect(
        container.read(featureFlagsProvider)[FeatureFlag.backgroundAlerts],
        isFalse,
      );

      await notifier.toggle(FeatureFlag.backgroundAlerts);
      expect(
        container.read(featureFlagsProvider)[FeatureFlag.backgroundAlerts],
        isTrue,
      );
    });

    test('resetAll clears state and storage', () async {
      final store = InMemoryFeatureFlagStore({FeatureFlag.authentication: true});
      final container = containerWith(store);

      await container.read(featureFlagsProvider.notifier).resetAll();

      expect(
        container.read(featureFlagsProvider)[FeatureFlag.authentication],
        isFalse,
      );
      expect(store.readOverrides(), isEmpty);
    });

    test('featureFlagProvider exposes a single flag', () {
      final container = containerWith(
        InMemoryFeatureFlagStore({FeatureFlag.remoteRules: true}),
      );

      expect(container.read(featureFlagProvider(FeatureFlag.remoteRules)), isTrue);
      expect(
        container.read(featureFlagProvider(FeatureFlag.authentication)),
        isFalse,
      );
    });
  });

  group('FlagGate', () {
    Widget harness(FeatureFlagStore store, Widget child) {
      return ProviderScope(
        overrides: [featureFlagStoreProvider.overrideWithValue(store)],
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );
    }

    testWidgets('renders the child when the flag is on', (tester) async {
      await tester.pumpWidget(
        harness(
          InMemoryFeatureFlagStore({FeatureFlag.authentication: true}),
          const FlagGate(
            flag: FeatureFlag.authentication,
            child: Text('sign in'),
          ),
        ),
      );

      expect(find.text('sign in'), findsOneWidget);
    });

    testWidgets('renders nothing when the flag is off', (tester) async {
      await tester.pumpWidget(
        harness(
          InMemoryFeatureFlagStore(),
          const FlagGate(
            flag: FeatureFlag.authentication,
            child: Text('sign in'),
          ),
        ),
      );

      expect(find.text('sign in'), findsNothing);
    });

    testWidgets('renders the fallback when the flag is off', (tester) async {
      await tester.pumpWidget(
        harness(
          InMemoryFeatureFlagStore(),
          const FlagGate(
            flag: FeatureFlag.authentication,
            fallback: Text('coming soon'),
            child: Text('sign in'),
          ),
        ),
      );

      expect(find.text('sign in'), findsNothing);
      expect(find.text('coming soon'), findsOneWidget);
    });

    testWidgets('reacts when the flag is toggled at runtime', (tester) async {
      final store = InMemoryFeatureFlagStore();
      final scope = ProviderScope(
        overrides: [featureFlagStoreProvider.overrideWithValue(store)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: FlagGate(
            flag: FeatureFlag.authentication,
            child: Text('sign in'),
          ),
        ),
      );
      await tester.pumpWidget(scope);
      expect(find.text('sign in'), findsNothing);

      final element = tester.element(find.byType(FlagGate));
      final container = ProviderScope.containerOf(element);
      await container
          .read(featureFlagsProvider.notifier)
          .setOverride(FeatureFlag.authentication, true);
      await tester.pump();

      expect(find.text('sign in'), findsOneWidget);
    });
  });
}
