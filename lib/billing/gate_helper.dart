import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_providers.dart';

/// Derives the effective Pro entitlement.
///
/// Returns `false` when the billing state is loading or in error (safe default).
/// This is the single source of truth for all Pro/Free gates.
final effectiveIsProProvider = Provider<bool>((ref) {
  return ref.watch(billingProvider).whenOrNull(data: (d) => d.isPro) ?? false;
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
