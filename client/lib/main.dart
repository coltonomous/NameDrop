import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/celebrity_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = CelebrityService();
  await service.init();

  runApp(NameDropApp(service: service));
}

class NameDropApp extends StatelessWidget {
  final CelebrityService service;

  const NameDropApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NameDrop',
      theme: NameDropTheme.build(),
      home: HomeScreen(service: service),
    );
  }
}
