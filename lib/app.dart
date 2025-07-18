import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';

class DisConXApp extends StatelessWidget {
  const DisConXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DisConX | DICT Secure Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}