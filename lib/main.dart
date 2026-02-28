import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'ui/shell/app_shell.dart';

void main() {
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
