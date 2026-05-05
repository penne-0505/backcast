import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'pro_entitlement_repository.dart';

final proEntitlementRepositoryProvider = Provider<ProEntitlementRepository>((
  ref,
) {
  return ProEntitlementRepository(Supabase.instance.client);
});

final currentProEntitlementProvider = FutureProvider<ProEntitlementState>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const ProEntitlementState.free();
  }

  final repository = ref.watch(proEntitlementRepositoryProvider);
  return repository.fetchCurrent(userId);
});
