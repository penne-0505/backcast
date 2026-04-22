import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Application-level subscription / billing state.
@immutable
class BillingState {
  const BillingState({this.isPro = false, this.isTrialing = false});

  final bool isPro;
  final bool isTrialing;

  BillingState copyWith({bool? isPro, bool? isTrialing}) => BillingState(
        isPro: isPro ?? this.isPro,
        isTrialing: isTrialing ?? this.isTrialing,
      );
}

/// Notifier that syncs RevenueCat [CustomerInfo] into a [BillingState].
class BillingNotifier extends AsyncNotifier<BillingState> {
  @override
  Future<BillingState> build() async {
    final customerInfo = await Purchases.getCustomerInfo();
    var current = _mapCustomerInfo(customerInfo);

    Purchases.addCustomerInfoUpdateListener((info) {
      current = _mapCustomerInfo(info);
      state = AsyncValue.data(current);
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

  /// Restore previous purchases and refresh the billing state.
  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      // Listener will automatically update state.
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
