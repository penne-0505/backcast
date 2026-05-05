import 'package:flutter/foundation.dart';

class RevenueCatConfig {
  /// RevenueCat public API key for Android.
  static const String androidApiKey = 'goog_xNiBgHwujAWHzaKdwRmuxMyrpkO';

  /// RevenueCat public API key for iOS / macOS.
  static const String iosApiKey = 'YOUR_IOS_API_KEY';

  /// Whether the current runtime can safely use the native RevenueCat SDK.
  static bool get supportsCurrentPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
  }

  /// Returns the appropriate API key for the current supported platform.
  static String? get currentApiKey {
    if (!supportsCurrentPlatform) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidApiKey,
      TargetPlatform.iOS || TargetPlatform.macOS => iosApiKey,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => null,
    };
  }
}
