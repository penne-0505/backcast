import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class ProEntitlementState {
  const ProEntitlementState({
    required this.isPro,
    required this.status,
    this.productId,
    this.expiresAt,
    this.lastSyncedAt,
  });

  const ProEntitlementState.free()
    : isPro = false,
      status = 'inactive',
      productId = null,
      expiresAt = null,
      lastSyncedAt = null;

  final bool isPro;
  final String status;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime? lastSyncedAt;

  static ProEntitlementState fromJson(Map<String, dynamic> json) {
    return ProEntitlementState(
      isPro: json['is_pro'] == true,
      status: json['status']?.toString() ?? 'inactive',
      productId: json['product_id']?.toString(),
      expiresAt: _parseDateTime(json['expires_at']),
      lastSyncedAt: _parseDateTime(json['last_synced_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class ProEntitlementRepository {
  const ProEntitlementRepository(this._client);

  final SupabaseClient _client;

  Future<ProEntitlementState> fetchCurrent(String userId) async {
    final row = await _client
        .from('user_pro_entitlements')
        .select('is_pro,status,product_id,expires_at,last_synced_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return const ProEntitlementState.free();
    }

    return ProEntitlementState.fromJson(row);
  }
}
