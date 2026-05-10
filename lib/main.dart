import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_providers.dart';
import 'billing/billing_providers.dart';
import 'billing/pro_entitlement_providers.dart';
import 'config/revenuecat_config.dart';
import 'config/supabase_config.dart';
import 'persistence/app_database.dart';
import 'persistence/persistence_providers.dart';
import 'theme.dart';
import 'timeline_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  final revenueCatApiKey = RevenueCatConfig.currentApiKey;
  if (revenueCatApiKey != null) {
    await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  }
  final db = AppDatabase.defaults();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MedoApp(),
    ),
  );
}

class MedoApp extends ConsumerWidget {
  const MedoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep RevenueCat identity in sync with Supabase auth state.
    ref.listen<String?>(currentUserIdProvider, (prev, next) async {
      if (next == null) {
        if (RevenueCatConfig.supportsCurrentPlatform && prev != null) {
          await Purchases.logOut();
        }
        ref.invalidate(currentProEntitlementProvider);
        return;
      }

      if (RevenueCatConfig.supportsCurrentPlatform && next != prev) {
        await Purchases.logIn(next);
      }
      await _syncReviewerEntitlement();
      ref.invalidate(currentProEntitlementProvider);
    });

    // Start listening to RevenueCat updates as soon as the app boots.
    ref.read(billingProvider);

    return MaterialApp(
      title: 'Medo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accentOlive,
          surface: AppColors.canvas,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.accentOlive,
          selectionColor: AppColors.textSelection,
          selectionHandleColor: AppColors.accentOlive,
        ),
      ),
      home: const TimelineScreen(),
    );
  }
}

Future<void> _syncReviewerEntitlement() async {
  try {
    await Supabase.instance.client.functions.invoke(
      'sync-reviewer-entitlement',
    );
  } catch (_) {
    // Reviewer access is best-effort. Normal paid / Free entitlement reads stay authoritative.
  }
}
