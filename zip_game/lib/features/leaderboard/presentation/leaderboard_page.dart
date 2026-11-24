import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/app_scope.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_view.dart';
import '../domain/leaderboard_entry.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = AppScope.of(context).leaderboardRepository.top();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).authController.user?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = AppScope.of(context).leaderboardRepository.top());
          await _future;
        },
        child: AsyncView<List<LeaderboardEntry>>(
          future: _future,
          isEmpty: (rows) => rows.isEmpty,
          emptyMessage: 'Aún no hay puntajes. ¡Sé el primero!',
          onRetry: () => setState(() => _future = AppScope.of(context).leaderboardRepository.top()),
          builder: (rows) => ListView(
            // En PC: columna centrada de máx. 760 px (los puntos quedan junto al nombre)
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: math.max(12, (MediaQuery.sizeOf(context).width - 760) / 2),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Regla: suma del mejor puntaje de cada nivel. '
                  'Empates: más niveles completados y luego menor tiempo total.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              for (final row in rows)
                Card(
                  color: row.userId == me ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: ListTile(
                    // Oro / plata / bronce con texto oscuro (antes blanco: no se leía)
                    leading: CircleAvatar(
                      backgroundColor: switch (row.rank) {
                        1 => Colors.amber,
                        2 => Colors.grey.shade400,
                        3 => Colors.brown.shade300,
                        _ => null,
                      },
                      foregroundColor: row.rank <= 3 ? Colors.black87 : null,
                      child: Text(
                        '${row.rank}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(row.username),
                    subtitle: Text(
                      '${row.levelsCompleted} niveles · ${formatDuration(row.totalTimeSeconds)}',
                    ),
                    trailing: Text(
                      '${row.totalScore}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
