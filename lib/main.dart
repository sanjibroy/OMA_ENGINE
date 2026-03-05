import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'ui/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.setPreventClose(true);
  });
  runApp(const OmaEngineApp());
}

class OmaEngineApp extends StatelessWidget {
  const OmaEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMA Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
