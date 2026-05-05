import 'package:flutter_test/flutter_test.dart';
import 'package:medo/billing/pro_entitlement_repository.dart';

void main() {
  group('ProEntitlementState', () {
    test('free state is inactive', () {
      const state = ProEntitlementState.free();

      expect(state.isPro, isFalse);
      expect(state.status, 'inactive');
      expect(state.productId, isNull);
    });

    test('parses Supabase row', () {
      final state = ProEntitlementState.fromJson({
        'is_pro': true,
        'status': 'trial',
        'product_id': 'medo_pro_monthly',
        'expires_at': '2026-06-01T00:00:00Z',
        'last_synced_at': '2026-05-09T00:00:00Z',
      });

      expect(state.isPro, isTrue);
      expect(state.status, 'trial');
      expect(state.productId, 'medo_pro_monthly');
      expect(state.expiresAt, DateTime.utc(2026, 6));
      expect(state.lastSyncedAt, DateTime.utc(2026, 5, 9));
    });
  });
}
