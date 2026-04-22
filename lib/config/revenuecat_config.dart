import 'dart:io';

class RevenueCatConfig {
  /// RevenueCat public API key for Android.
  static const String androidApiKey = 'goog_xNiBgHwujAWHzaKdwRmuxMyrpkO';

  /// RevenueCat public API key for iOS / macOS.
  static const String iosApiKey = 'YOUR_IOS_API_KEY';

  /// Returns the appropriate API key for the current platform.
  static String get currentApiKey {
    if (Platform.isAndroid) return androidApiKey;
    if (Platform.isIOS || Platform.isMacOS) return iosApiKey;
    return androidApiKey; // fallback for other platforms
  }
}
