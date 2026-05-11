import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pro_entitlement_providers.dart';
import 'pro_entitlement_repository.dart';

enum ProAccessStatus { loading, pro, free, error }

class ProAccessState {
  const ProAccessState({required this.status, this.entitlement, this.error});

  const ProAccessState.loading()
    : status = ProAccessStatus.loading,
      entitlement = null,
      error = null;

  const ProAccessState.pro()
    : status = ProAccessStatus.pro,
      entitlement = null,
      error = null;

  const ProAccessState.free()
    : status = ProAccessStatus.free,
      entitlement = null,
      error = null;

  factory ProAccessState.error(Object error) =>
      ProAccessState(status: ProAccessStatus.error, error: error);

  factory ProAccessState.known(ProEntitlementState entitlement) =>
      ProAccessState(
        status: entitlement.isPro ? ProAccessStatus.pro : ProAccessStatus.free,
        entitlement: entitlement,
      );

  final ProAccessStatus status;
  final ProEntitlementState? entitlement;
  final Object? error;

  bool get isKnown =>
      status == ProAccessStatus.pro || status == ProAccessStatus.free;
  bool get isPro => status == ProAccessStatus.pro;
  bool get isFree => status == ProAccessStatus.free;
  bool get isLoading => status == ProAccessStatus.loading;
  bool get hasError => status == ProAccessStatus.error;
}

/// Derives the effective Pro entitlement without collapsing loading/error into
/// Free. UI and action gates should avoid paywall routing until this is known.
final effectiveProAccessProvider = Provider<ProAccessState>((ref) {
  ProAccessState cachedOr(ProAccessState fallback) {
    final cached = ref.watch(cachedProEntitlementProvider);
    return cached.maybeWhen(
      data: (entitlement) =>
          entitlement == null ? fallback : ProAccessState.known(entitlement),
      orElse: () => fallback,
    );
  }

  final entitlement = ref.watch(currentProEntitlementProvider);
  return entitlement.when(
    data: ProAccessState.known,
    loading: () => cachedOr(const ProAccessState.loading()),
    error: (error, _) => cachedOr(ProAccessState.error(error)),
  );
});

/// Legacy bool projection for call sites that only need a confirmed Pro check.
/// Prefer [effectiveProAccessProvider] for UI/paywall gates.
final effectiveIsProProvider = Provider<bool>((ref) {
  return ref.watch(effectiveProAccessProvider).isPro;
});

/// The maximum number of timelines a Free user can keep.
const kFreeTimelineLimit = 2;

/// Feature contexts for the paywall screen.
enum PaywallFeature {
  /// Template-related gate.
  templates,

  /// Timeline count limit gate.
  timelineCount,

  /// Image export gate.
  imageExport,

  /// Action-level buffer editing gate.
  actionBuffer,
}
