import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../persistence/persistence_providers.dart';
import 'pro_entitlement_cache_repository.dart';
import 'pro_entitlement_repository.dart';

final proEntitlementRepositoryProvider = Provider<ProEntitlementRepository>((
  ref,
) {
  return ProEntitlementRepository(Supabase.instance.client);
});

final proEntitlementCacheRepositoryProvider =
    Provider<ProEntitlementCacheRepository>((ref) {
      return ProEntitlementCacheRepository(ref.watch(databaseProvider));
    });

final cachedProEntitlementProvider = FutureProvider<ProEntitlementState?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final repository = ref.watch(proEntitlementCacheRepositoryProvider);
  return repository.fetch(userId);
});

final currentProEntitlementProvider = FutureProvider<ProEntitlementState>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const ProEntitlementState.free();
  }

  final repository = ref.watch(proEntitlementRepositoryProvider);
  final entitlement = await repository.fetchCurrent(userId);
  final cacheRepository = ref.watch(proEntitlementCacheRepositoryProvider);
  await cacheRepository.save(userId, entitlement);
  ref.invalidate(cachedProEntitlementProvider);
  return entitlement;
});
