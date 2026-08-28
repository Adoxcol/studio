import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/app.dart';
import 'package:studio/core/window/window_bootstrap.dart';

Future<void> main() async {
  await bootstrapWindow();
  runApp(const ProviderScope(child: StudioApp()));
}
