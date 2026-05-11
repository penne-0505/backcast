import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medo/billing/gate_helper.dart';
import 'package:medo/billing/pro_entitlement_providers.dart';
import 'package:medo/billing/pro_entitlement_repository.dart';

void main() {
  group('effectiveProAccessProvider', () {
    test('keeps loading separate from Free', () {
      final container = ProviderContainer(
        overrides: [
          cachedProEntitlementProvider.overrideWith((_) async => null),
          currentProEntitlementProvider.overrideWith(
            (_) => Future<ProEntitlementState>.delayed(
              const Duration(minutes: 1),
              () => const ProEntitlementState.free(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final access = container.read(effectiveProAccessProvider);

      expect(access.status, ProAccessStatus.loading);
      expect(access.isKnown, isFalse);
      expect(access.isFree, isFalse);
      expect(container.read(effectiveIsProProvider), isFalse);
    });

    test('maps known Free and Pro states explicitly', () async {
      final freeContainer = ProviderContainer(
        overrides: [
          cachedProEntitlementProvider.overrideWith((_) async => null),
          currentProEntitlementProvider.overrideWith(
            (_) async => const ProEntitlementState.free(),
          ),
        ],
      );
      addTearDown(freeContainer.dispose);

      await freeContainer.read(currentProEntitlementProvider.future);
      expect(
        freeContainer.read(effectiveProAccessProvider).status,
        ProAccessStatus.free,
      );

      final proContainer = ProviderContainer(
        overrides: [
          cachedProEntitlementProvider.overrideWith((_) async => null),
          currentProEntitlementProvider.overrideWith(
            (_) async =>
                const ProEntitlementState(isPro: true, status: 'active'),
          ),
        ],
      );
      addTearDown(proContainer.dispose);

      await proContainer.read(currentProEntitlementProvider.future);
      expect(
        proContainer.read(effectiveProAccessProvider).status,
        ProAccessStatus.pro,
      );
      expect(proContainer.read(effectiveIsProProvider), isTrue);
    });

    test('uses cached state while server entitlement is loading', () async {
      final container = ProviderContainer(
        overrides: [
          cachedProEntitlementProvider.overrideWith(
            (_) async =>
                const ProEntitlementState(isPro: true, status: 'active'),
          ),
          currentProEntitlementProvider.overrideWith(
            (_) => Future<ProEntitlementState>.delayed(
              const Duration(minutes: 1),
              () => const ProEntitlementState.free(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cachedProEntitlementProvider.future);

      final access = container.read(effectiveProAccessProvider);
      expect(access.status, ProAccessStatus.pro);
      expect(container.read(effectiveIsProProvider), isTrue);
    });

    test('uses cached state when server entitlement read fails', () async {
      final container = ProviderContainer(
        overrides: [
          cachedProEntitlementProvider.overrideWith(
            (_) async =>
                const ProEntitlementState(isPro: true, status: 'active'),
          ),
          currentProEntitlementProvider.overrideWith(
            (_) async => throw StateError('network unavailable'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cachedProEntitlementProvider.future);
      await expectLater(
        container.read(currentProEntitlementProvider.future),
        throwsStateError,
      );

      final access = container.read(effectiveProAccessProvider);
      expect(access.status, ProAccessStatus.pro);
      expect(access.hasError, isFalse);
    });
  });
}
