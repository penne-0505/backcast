import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Color Palette
// ---------------------------------------------------------------------------

abstract final class AppColors {
  static const canvas = Color(0xFFF6F5F2);
  static const softGray = Color(0xFFDDD9D0);
  static const ink = Color(0xFF26241F);
  static const mutedInk = Color(0xFF6F6A61);
  static const accentOlive = Color(0xFF8A9864);
  static const darkSurface = Color(0xFF1F211C);

  // Card system
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardBackgroundSelected = Color(0xFFF8F8F6);
  static const timelineLine = Color(0xFFD5D2CC);

  // 指定パレットからの透明度違いのみを許容し、別色は増やさない。
  static const selectionFill = Color(0x248A9864);
  static const accentDivider = Color(0x448A9864);
  static const textSelection = Color(0x338A9864);
  static const scrim = Color(0x331F211C);
  static const softShadow = Color(0x141F211C);
  static const elevatedShadow = Color(0x1F1F211C);

  // よりくすんだ、キャンバスと調和するブロック色
  static const List<Color> blockColors = [
    Color(0xFF7A8B9E), // dusty blue
    Color(0xFF9E7E6E), // dusty terracotta
    Color(0xFF9E8E6E), // dusty gold
    Color(0xFF8E7E8E), // dusty purple
    Color(0xFF6E8E86), // dusty teal
  ];
}

// ---------------------------------------------------------------------------
// Spacing Tokens
// ---------------------------------------------------------------------------

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

// ---------------------------------------------------------------------------
// Border Radius Tokens
// ---------------------------------------------------------------------------

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 99;
}

// ---------------------------------------------------------------------------
// Shadows
// ---------------------------------------------------------------------------

abstract final class AppShadows {
  static List<BoxShadow> get floatingToolbar => [
    BoxShadow(
      color: AppColors.accentOlive.withValues(alpha: 0.35),
      blurRadius: 28,
      spreadRadius: 2,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.accentOlive.withValues(alpha: 0.12),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get sheet => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> get workSurface => sheet;

  static List<BoxShadow> get quickOverlay => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.14),
      blurRadius: 28,
      spreadRadius: -4,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.08),
      blurRadius: 10,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get panel => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.06),
      blurRadius: 12,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardSelected => [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.10),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> header = [
    BoxShadow(
      color: AppColors.softShadow,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

abstract final class AppTextStyles {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle time({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: _tabular,
    );
  }

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.mutedInk,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedInk,
  );
}

// ---------------------------------------------------------------------------
// Pressable — シンプルなタップ/ロングプレスラッパー
// ---------------------------------------------------------------------------

class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.behavior = HitTestBehavior.opaque,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final HitTestBehavior behavior;
  final double scale;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// ShakeWidget — 無効操作時のシェイクフィードバック（現在は透過）
// ---------------------------------------------------------------------------

class ShakeWidget extends StatelessWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 8.0,
  });

  final Widget child;
  final bool shake;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
