import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../auth/auth_providers.dart';
import '../config/revenuecat_config.dart';
import 'pro_entitlement_providers.dart';

/// Thin gateway around RevenueCat static APIs.
///
/// Keeping the SDK boundary injectable makes purchase and offering state
/// testable without invoking platform channels.
class RevenueCatGateway {
  const RevenueCatGateway();

  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchasePackage(Package package) =>
      Purchases.purchasePackage(package);

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  Future<CustomerInfo> logIn(String appUserId) async {
    final result = await Purchases.logIn(appUserId);
    return result.customerInfo;
  }

  Future<CustomerInfo> logOut() => Purchases.logOut();

  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo customerInfo) listener,
  ) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }
}

final revenueCatGatewayProvider = Provider<RevenueCatGateway>((ref) {
  return const RevenueCatGateway();
});

final revenueCatBillingAvailableProvider = Provider<bool>((ref) {
  return RevenueCatConfig.supportsCurrentPlatform;
});

enum RevenueCatIdentityStatus { signedOut, syncing, synced, unavailable, error }

@immutable
class RevenueCatIdentityState {
  const RevenueCatIdentityState._({
    required this.status,
    this.userId,
    this.error,
  });

  const RevenueCatIdentityState.signedOut()
    : this._(status: RevenueCatIdentityStatus.signedOut);

  const RevenueCatIdentityState.syncing(String userId)
    : this._(status: RevenueCatIdentityStatus.syncing, userId: userId);

  const RevenueCatIdentityState.synced(String userId)
    : this._(status: RevenueCatIdentityStatus.synced, userId: userId);

  const RevenueCatIdentityState.unavailable(String userId)
    : this._(status: RevenueCatIdentityStatus.unavailable, userId: userId);

  const RevenueCatIdentityState.error(String userId, Object error)
    : this._(
        status: RevenueCatIdentityStatus.error,
        userId: userId,
        error: error,
      );

  final RevenueCatIdentityStatus status;
  final String? userId;
  final Object? error;

  bool get isSyncing => status == RevenueCatIdentityStatus.syncing;
  bool isSyncedFor(String expectedUserId) =>
      status == RevenueCatIdentityStatus.synced && userId == expectedUserId;
}

class RevenueCatIdentityNotifier extends Notifier<RevenueCatIdentityState> {
  @override
  RevenueCatIdentityState build() => const RevenueCatIdentityState.signedOut();

  void setSignedOut() => state = const RevenueCatIdentityState.signedOut();

  void setSyncing(String userId) {
    state = RevenueCatIdentityState.syncing(userId);
  }

  void setSynced(String userId) {
    state = RevenueCatIdentityState.synced(userId);
  }

  void setUnavailable(String userId) {
    state = RevenueCatIdentityState.unavailable(userId);
  }

  void setError(String userId, Object error) {
    state = RevenueCatIdentityState.error(userId, error);
  }
}

final revenueCatIdentityProvider =
    NotifierProvider<RevenueCatIdentityNotifier, RevenueCatIdentityState>(
      RevenueCatIdentityNotifier.new,
    );

/// Application-level subscription / billing state.
@immutable
class BillingState {
  const BillingState({
    this.isPro = false,
    this.isTrialing = false,
    this.purchaseStatus = BillingPurchaseStatus.idle,
    this.purchaseMessage,
  });

  final bool isPro;
  final bool isTrialing;
  final BillingPurchaseStatus purchaseStatus;
  final String? purchaseMessage;

  bool get isBusy =>
      purchaseStatus == BillingPurchaseStatus.purchasing ||
      purchaseStatus == BillingPurchaseStatus.restoring;

  BillingState copyWith({
    bool? isPro,
    bool? isTrialing,
    BillingPurchaseStatus? purchaseStatus,
    String? purchaseMessage,
    bool clearPurchaseMessage = false,
  }) => BillingState(
    isPro: isPro ?? this.isPro,
    isTrialing: isTrialing ?? this.isTrialing,
    purchaseStatus: purchaseStatus ?? this.purchaseStatus,
    purchaseMessage: clearPurchaseMessage
        ? null
        : purchaseMessage ?? this.purchaseMessage,
  );
}

enum BillingPurchaseStatus {
  idle,
  purchasing,
  restoring,
  purchasePending,
  restored,
  cancelled,
  failed,
}

@immutable
class ProPackageState {
  const ProPackageState({
    required this.package,
    required this.displayPrice,
    required this.periodLabel,
    required this.productTitle,
  });

  final Package package;
  final String displayPrice;
  final String periodLabel;
  final String productTitle;
}

final proPackageProvider = FutureProvider<ProPackageState?>((ref) async {
  if (!ref.watch(revenueCatBillingAvailableProvider)) return null;

  final offerings = await ref.watch(revenueCatGatewayProvider).getOfferings();
  final offering = offerings.current;
  if (offering == null || offering.availablePackages.isEmpty) {
    return null;
  }

  final package =
      offering.monthly ?? offering.annual ?? offering.availablePackages.first;
  final product = package.storeProduct;
  return ProPackageState(
    package: package,
    displayPrice: product.priceString,
    periodLabel: _periodLabel(product.subscriptionPeriod, package.packageType),
    productTitle: product.title,
  );
});

final subscriptionManagementUrlProvider = FutureProvider<Uri?>((ref) async {
  if (!ref.watch(revenueCatBillingAvailableProvider)) return null;
  if (ref.watch(currentUserIdProvider) == null) return null;

  final customerInfo = await ref
      .watch(revenueCatGatewayProvider)
      .getCustomerInfo();
  final rawUrl = customerInfo.managementURL?.trim();
  if (rawUrl == null || rawUrl.isEmpty) return null;

  return Uri.tryParse(rawUrl);
});

/// Notifier that syncs RevenueCat [CustomerInfo] into a [BillingState].
class BillingNotifier extends AsyncNotifier<BillingState> {
  @override
  Future<BillingState> build() async {
    if (!ref.watch(revenueCatBillingAvailableProvider)) {
      return const BillingState();
    }
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const BillingState();
    }

    final gateway = ref.watch(revenueCatGatewayProvider);
    final customerInfo = await gateway.getCustomerInfo();
    var current = _mapCustomerInfo(customerInfo);

    gateway.addCustomerInfoUpdateListener((info) {
      current = _mapCustomerInfo(info);
      state = AsyncValue.data(current);
      ref.invalidate(currentProEntitlementProvider);
    });

    return current;
  }

  BillingState _mapCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.all['pro'];
    return BillingState(
      isPro: entitlement?.isActive ?? false,
      isTrialing: entitlement?.periodType == PeriodType.trial,
    );
  }

  Future<void> purchaseProPackage(Package package) async {
    final previous = state.maybeWhen(
      data: (value) => value,
      orElse: () => const BillingState(),
    );
    if (!ref.read(revenueCatBillingAvailableProvider)) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: 'この環境ではアプリ内購入を利用できません。',
        ),
      );
      return;
    }
    if (ref.read(currentUserIdProvider) == null) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: 'Proの購入にはログインが必要です。設定からログインしてください。',
        ),
      );
      return;
    }
    if (!_isRevenueCatIdentityReady()) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: _revenueCatIdentityMessage('Proの購入'),
        ),
      );
      return;
    }

    state = AsyncValue.data(
      previous.copyWith(
        purchaseStatus: BillingPurchaseStatus.purchasing,
        clearPurchaseMessage: true,
      ),
    );

    try {
      final customerInfo = await ref
          .read(revenueCatGatewayProvider)
          .purchasePackage(package);
      final next = _mapCustomerInfo(customerInfo).copyWith(
        purchaseStatus: BillingPurchaseStatus.purchasePending,
        purchaseMessage: '購入を確認中です。反映まで少し時間がかかる場合があります。',
      );
      state = AsyncValue.data(next);
      _refreshEntitlementBoundary();
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        state = AsyncValue.data(
          previous.copyWith(
            purchaseStatus: BillingPurchaseStatus.cancelled,
            purchaseMessage: '購入はキャンセルされました。',
          ),
        );
      } else {
        state = AsyncValue.data(
          previous.copyWith(
            purchaseStatus: BillingPurchaseStatus.failed,
            purchaseMessage: '購入を完了できませんでした。時間をおいて再試行してください。',
          ),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Restore previous purchases and refresh the billing state.
  Future<void> restorePurchases() async {
    final previous = state.maybeWhen(
      data: (value) => value,
      orElse: () => const BillingState(),
    );
    if (!ref.read(revenueCatBillingAvailableProvider)) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: 'この環境では購入の復元を利用できません。',
        ),
      );
      return;
    }
    if (ref.read(currentUserIdProvider) == null) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: '購入の復元にはログインが必要です。設定からログインしてください。',
        ),
      );
      return;
    }
    if (!_isRevenueCatIdentityReady()) {
      state = AsyncValue.data(
        previous.copyWith(
          purchaseStatus: BillingPurchaseStatus.failed,
          purchaseMessage: _revenueCatIdentityMessage('購入の復元'),
        ),
      );
      return;
    }

    state = AsyncValue.data(
      previous.copyWith(
        purchaseStatus: BillingPurchaseStatus.restoring,
        clearPurchaseMessage: true,
      ),
    );

    try {
      final customerInfo = await ref
          .read(revenueCatGatewayProvider)
          .restorePurchases();
      state = AsyncValue.data(
        _mapCustomerInfo(customerInfo).copyWith(
          purchaseStatus: BillingPurchaseStatus.restored,
          purchaseMessage: '購入情報を復元しました。Pro状態を再確認しています。',
        ),
      );
      _refreshEntitlementBoundary();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _refreshEntitlementBoundary() {
    ref.invalidate(currentProEntitlementProvider);
    ref.invalidate(proPackageProvider);
  }

  bool _isRevenueCatIdentityReady() {
    if (!ref.read(revenueCatBillingAvailableProvider)) return true;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    return ref.read(revenueCatIdentityProvider).isSyncedFor(userId);
  }

  String _revenueCatIdentityMessage(String actionName) {
    final identity = ref.read(revenueCatIdentityProvider);
    if (identity.isSyncing) {
      return '$actionNameの準備中です。数秒後にもう一度お試しください。';
    }
    return '$actionNameの準備を完了できませんでした。ログイン状態を確認して再試行してください。';
  }
}

/// Global provider for billing / subscription state.
final billingProvider = AsyncNotifierProvider<BillingNotifier, BillingState>(
  BillingNotifier.new,
);

/// Derives whether the user currently has an active Pro entitlement.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(billingProvider).whenOrNull(data: (d) => d.isPro) ?? false;
});

/// Derives whether the user is currently in a trial period.
final isTrialingProvider = Provider<bool>((ref) {
  return ref.watch(billingProvider).whenOrNull(data: (d) => d.isTrialing) ??
      false;
});

String _periodLabel(String? subscriptionPeriod, PackageType packageType) {
  switch (subscriptionPeriod) {
    case 'P1W':
      return '週額';
    case 'P1M':
      return '月額';
    case 'P2M':
      return '2か月';
    case 'P3M':
      return '3か月';
    case 'P6M':
      return '6か月';
    case 'P1Y':
      return '年額';
  }

  switch (packageType) {
    case PackageType.weekly:
      return '週額';
    case PackageType.monthly:
      return '月額';
    case PackageType.twoMonth:
      return '2か月';
    case PackageType.threeMonth:
      return '3か月';
    case PackageType.sixMonth:
      return '6か月';
    case PackageType.annual:
      return '年額';
    case PackageType.lifetime:
      return '買い切り';
    case PackageType.custom:
    case PackageType.unknown:
      return 'Pro';
  }
}
