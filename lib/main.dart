import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';
import 'timeline_screen.dart';

void main() {
  runApp(const ProviderScope(child: BackcastApp()));
}

class BackcastApp extends StatelessWidget {
  const BackcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backcast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: AppColors.stone50,
        colorScheme: const ColorScheme.light(
          primary: AppColors.blue500,
          surface: Colors.white,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.blue500,
          selectionColor: Color(0x33F97316),
          selectionHandleColor: AppColors.blue500,
        ),
      ),
      home: const TimelineScreen(),
    );
  }
}
