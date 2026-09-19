import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme.dart';
import 'main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: HoppersApp()));
}

class HoppersApp extends StatelessWidget {
  const HoppersApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoppers',
      debugShowCheckedModeBanner: false,
      theme: buildHoppersTheme(),
      home: const MainScreen(),
    );
  }
}