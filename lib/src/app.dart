import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode(settings.themeMode),
      home: const HomeScreen(),
    );
  }

  ThemeMode _themeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}