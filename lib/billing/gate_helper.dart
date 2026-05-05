import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pro_entitlement_providers.dart';

/// Derives the effective Pro entitlement.
///
/// Returns `false` when the server entitlement is loading or in error.
/// This is the single source of truth for all Pro/Free gates.
final effectiveIsProProvider = Provider<bool>((ref) {
  return ref
      .watch(currentProEntitlementProvider)
      .maybeWhen(data: (entitlement) => entitlement.isPro, orElse: () => false);
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
}
