import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/celebrity_service.dart';
import 'services/stats_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = CelebrityService();
  final stats = StatsService();
  await Future.wait([service.init(), stats.init()]);

  runApp(NameDropApp(service: service, stats: stats));
}

class NameDropApp extends StatelessWidget {
  final CelebrityService service;
  final StatsService stats;

  const NameDropApp({super.key, required this.service, required this.stats});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NameDrop',
      theme: NameDropTheme.build(),
      home: HomeScreen(service: service, stats: stats),
    );
  }
}
