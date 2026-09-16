import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/database/app_database.dart';
import 'src/providers/providers.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    AppDatabase.initFfi();
  }
  runApp(const ProviderScope(child: VLogApp()));
}

class VLogApp extends ConsumerWidget {
  const VLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(appSettingsNotifierProvider).when(
          data: (settings) => App(settings: settings),
          loading: () => const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
          error: (error, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: Text('Failed to load: $error'))),
          ),
        );
  }
}
