import 'package:flutter/material.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/layout/studio_shell.dart';

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.light(),
      darkTheme: StudioTheme.dark(),
      themeMode: ThemeMode.light,
      home: const StudioShell(),
    );
  }
}
