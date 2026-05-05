import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medo/billing/billing_providers.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('proPackageProvider', () {
    test('selects monthly package from current offering', () async {
      final container = ProviderContainer(
        overrides: [
          revenueCatBillingAvailableProvider.overrideWithValue(true),
          revenueCatGatewayProvider.overrideWithValue(
            _FakeRevenueCatGateway(offerings: _offeringsWithMonthlyPackage()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final package = await container.read(proPackageProvider.future);

      expect(package, isNotNull);
      expect(package!.displayPrice, '¥480');
      expect(package.periodLabel, '月額');
      expect(package.productTitle, 'Medo Pro');
    });

    test('returns null when current offering has no packages', () async {
      final container = ProviderContainer(
        overrides: [
          revenueCatBillingAvailableProvider.overrideWithValue(true),
          revenueCatGatewayProvider.overrideWithValue(
            _FakeRevenueCatGateway(offerings: _emptyOfferings()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final package = await container.read(proPackageProvider.future);

      expect(package, isNull);
    });

    test('purchase cancellation becomes recoverable billing state', () async {
      final gateway = _FakeRevenueCatGateway(
        offerings: _offeringsWithMonthlyPackage(),
        purchaseError: PlatformException(code: '1'),
      );
      final container = ProviderContainer(
        overrides: [
          revenueCatBillingAvailableProvider.overrideWithValue(true),
          revenueCatGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(billingProvider.future);
      final package = await container.read(proPackageProvider.future);
      await container
          .read(billingProvider.notifier)
          .purchaseProPackage(package!.package);

      final state = container.read(billingProvider).requireValue;
      expect(state.purchaseStatus, BillingPurchaseStatus.cancelled);
      expect(state.purchaseMessage, '購入はキャンセルされました。');
    });

    test('successful purchase enters pending verification state', () async {
      final gateway = _FakeRevenueCatGateway(
        offerings: _offeringsWithMonthlyPackage(),
      );
      final container = ProviderContainer(
        overrides: [
          revenueCatBillingAvailableProvider.overrideWithValue(true),
          revenueCatGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(billingProvider.future);
      final package = await container.read(proPackageProvider.future);
      await container
          .read(billingProvider.notifier)
          .purchaseProPackage(package!.package);

      final state = container.read(billingProvider).requireValue;
      expect(gateway.purchaseCount, 1);
      expect(state.purchaseStatus, BillingPurchaseStatus.purchasePending);
      expect(state.purchaseMessage, '購入を確認中です。反映まで少し時間がかかる場合があります。');
    });

    test(
      'restore uses RevenueCat and enters restored verification state',
      () async {
        final gateway = _FakeRevenueCatGateway(
          offerings: _offeringsWithMonthlyPackage(),
        );
        final container = ProviderContainer(
          overrides: [
            revenueCatBillingAvailableProvider.overrideWithValue(true),
            revenueCatGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(container.dispose);

        await container.read(billingProvider.future);
        await container.read(billingProvider.notifier).restorePurchases();

        final state = container.read(billingProvider).requireValue;
        expect(gateway.restoreCount, 1);
        expect(state.purchaseStatus, BillingPurchaseStatus.restored);
        expect(state.purchaseMessage, '購入情報を復元しました。Pro状態を再確認しています。');
      },
    );

    test(
      'unsupported platforms stay Free without calling RevenueCat',
      () async {
        final gateway = _FakeRevenueCatGateway(
          offerings: _offeringsWithMonthlyPackage(),
        );
        final container = ProviderContainer(
          overrides: [
            revenueCatBillingAvailableProvider.overrideWithValue(false),
            revenueCatGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(container.dispose);

        final billing = await container.read(billingProvider.future);
        final package = await container.read(proPackageProvider.future);
        await container.read(billingProvider.notifier).restorePurchases();

        final restoredState = container.read(billingProvider).requireValue;
        expect(billing.isPro, isFalse);
        expect(package, isNull);
        expect(gateway.customerInfoCount, 0);
        expect(gateway.offeringsCount, 0);
        expect(gateway.restoreCount, 0);
        expect(restoredState.purchaseStatus, BillingPurchaseStatus.failed);
        expect(restoredState.purchaseMessage, 'この環境では購入の復元を利用できません。');
      },
    );
  });
}

class _FakeRevenueCatGateway extends RevenueCatGateway {
  _FakeRevenueCatGateway({required this.offerings, this.purchaseError});

  final Offerings offerings;
  final PlatformException? purchaseError;
  int customerInfoCount = 0;
  int offeringsCount = 0;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  Future<Offerings> getOfferings() async {
    offeringsCount += 1;
    return offerings;
  }

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    customerInfoCount += 1;
    return _customerInfo();
  }

  @override
  Future<CustomerInfo> purchasePackage(Package package) async {
    purchaseCount += 1;
    final error = purchaseError;
    if (error != null) {
      throw error;
    }
    return _customerInfo();
  }

  @override
  Future<CustomerInfo> restorePurchases() async {
    restoreCount += 1;
    return _customerInfo();
  }

  @override
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo customerInfo) listener,
  ) {}
}

Offerings _offeringsWithMonthlyPackage() {
  final json = {
    'all': <String, Object?>{},
    'current': {
      'identifier': 'current',
      'serverDescription': 'Current Pro offering',
      'metadata': <String, Object?>{},
      'availablePackages': [
        {
          'identifier': r'$rc_monthly',
          'packageType': 'MONTHLY',
          'product': {
            'identifier': 'medo_pro_monthly',
            'description': 'Medo Pro monthly subscription',
            'title': 'Medo Pro',
            'price': 480.0,
            'priceString': '¥480',
            'currencyCode': 'JPY',
            'introPrice': null,
            'discounts': null,
            'productCategory': null,
            'defaultOption': null,
            'subscriptionOptions': null,
            'presentedOfferingContext': null,
            'subscriptionPeriod': 'P1M',
          },
          'presentedOfferingContext': {
            'offeringIdentifier': 'current',
            'placementIdentifier': null,
            'targetingContext': null,
          },
        },
      ],
      'lifetime': null,
      'annual': null,
      'sixMonth': null,
      'threeMonth': null,
      'twoMonth': null,
      'monthly': {
        'identifier': r'$rc_monthly',
        'packageType': 'MONTHLY',
        'product': {
          'identifier': 'medo_pro_monthly',
          'description': 'Medo Pro monthly subscription',
          'title': 'Medo Pro',
          'price': 480.0,
          'priceString': '¥480',
          'currencyCode': 'JPY',
          'introPrice': null,
          'discounts': null,
          'productCategory': null,
          'defaultOption': null,
          'subscriptionOptions': null,
          'presentedOfferingContext': null,
          'subscriptionPeriod': 'P1M',
        },
        'presentedOfferingContext': {
          'offeringIdentifier': 'current',
          'placementIdentifier': null,
          'targetingContext': null,
        },
      },
      'weekly': null,
    },
  };
  return Offerings.fromJson(json);
}

Offerings _emptyOfferings() {
  const json = {
    'all': <String, Object?>{},
    'current': {
      'identifier': 'current',
      'serverDescription': 'Current Pro offering',
      'metadata': <String, Object?>{},
      'availablePackages': <Object?>[],
      'lifetime': null,
      'annual': null,
      'sixMonth': null,
      'threeMonth': null,
      'twoMonth': null,
      'monthly': null,
      'weekly': null,
    },
  };
  return Offerings.fromJson(json);
}

CustomerInfo _customerInfo() {
  return CustomerInfo(
    const EntitlementInfos({}, {}),
    const {},
    const [],
    const [],
    const [],
    '2026-05-09T00:00:00Z',
    'user-id',
    const {},
    '2026-05-09T00:00:00Z',
  );
}
