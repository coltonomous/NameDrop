import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/celebrity_service.dart';
import 'services/game_persistence_service.dart';
import 'services/stats_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NameDropApp());
}

class NameDropApp extends StatefulWidget {
  const NameDropApp({super.key});

  @override
  State<NameDropApp> createState() => _NameDropAppState();
}

class _NameDropAppState extends State<NameDropApp> {
  late final Future<(CelebrityService, StatsService, GamePersistenceService)>
      _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<(CelebrityService, StatsService, GamePersistenceService)>
      _init() async {
    final service = CelebrityService();
    final stats = StatsService();
    final persistence = GamePersistenceService();
    await Future.wait([service.init(), stats.init(), persistence.init()]);
    return (service, stats, persistence);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NameDrop',
      theme: NameDropTheme.build(),
      home: FutureBuilder<
          (CelebrityService, StatsService, GamePersistenceService)>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: NameDropTheme.navy,
              body: Center(
                child: CircularProgressIndicator(color: NameDropTheme.gold),
              ),
            );
          }
          final (service, stats, persistence) = snapshot.data!;
          return HomeScreen(
            service: service,
            stats: stats,
            persistence: persistence,
          );
        },
      ),
    );
  }
}
