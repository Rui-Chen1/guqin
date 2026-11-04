import 'package:flutter/material.dart';

import 'features/home/splash_page.dart';
import 'theme/app_theme.dart';

class GuqinApp extends StatelessWidget {
  const GuqinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '弦上知音',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashPage(),
    );
  }
}
