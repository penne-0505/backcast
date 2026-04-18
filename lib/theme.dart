import 'package:flutter/material.dart';

abstract final class AppColors {
  static const appBackground = Color(0xFFFFFFFF);

  static const stone50 = Color(0xFFF3F8FB); // appBackground と同値（サイドバーラベルマスク用）
  static const stone100 = Color(0xFFE9EEF1);
  static const stone200 = Color(0xFFE2EAEE);
  static const stone300 = Color(0xFF99A2A7);
  static const stone400 = Color(0xFF7F8B91);
  static const stone500 = Color(0xFF6F767A);
  static const stone700 = Color(0xFF4B5256);
  static const stone800 = Color(0xFF080D12);
  static const stone900 = Color(0xFF080D12);

  static const blue50 = Color(0xFFEBF6FF);
  static const blue400 = Color(0xFF24AFFF);
  static const blue500 = Color(0xFF0089F2);

  static const red50 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFFDC2626);

  static const List<Color> blockColors = [
    Color(0xFF60A5FA), // blue-400
    Color(0xFF34D399), // emerald-400
    Color(0xFFFBBF24), // amber-400
    Color(0xFFFB7185), // rose-400
    Color(0xFFC084FC), // purple-400
    Color(0xFF22D3EE), // cyan-400
  ];
}
