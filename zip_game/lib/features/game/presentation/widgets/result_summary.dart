import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/game_entities.dart';

/// Resumen del resultado VALIDADO por el backend.
class ResultSummary extends StatelessWidget {
  const ResultSummary({
    super.key,
    required this.result,
    required this.onPlayNext,
    required this.onBack,
  });

  final GameResult result;
  final VoidCallback onPlayNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    // Verde suave mezclado con la superficie: legible en tema claro y oscuro
    final background = Color.alphaBlend(
      Colors.green.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10),
      scheme.surfaceContainerLow,
    );
    final b = result.breakdown;
    final changeText = switch (result.difficultyChange) {
      'increase' =>
        '¡Subes de dificultad! Próximo reto: ${difficultyLabel(result.recommendedDifficulty)}',
      'decrease' => 'Bajamos la dificultad a ${difficultyLabel(result.recommendedDifficulty)}',
      _ => 'Dificultad recomendada: ${difficultyLabel(result.recommendedDifficulty)}',
    };

    return Card(
      key: const Key('result_summary'),
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        // Versión compacta: cabe junto al tablero sin tener que hacer scroll
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, size: 32, color: Colors.amber),
                const SizedBox(width: 8),
                Text('¡Puzzle resuelto!', style: text.titleLarge),
              ],
            ),
            Text(
              '${result.points} puntos',
              key: const Key('result_points'),
              style: text.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric(context, 'Tiempo', formatDuration(result.durationSeconds)),
                _metric(context, 'Errores', '${result.mistakes}'),
                _metric(context, 'Pistas', '${result.hintsUsed}'),
              ],
            ),
            const Divider(height: 20),
            _row('Base', '+${b['base'] ?? 0}'),
            _row('Bonus de tiempo', '+${b['time_bonus'] ?? 0}'),
            _row('Penalización tiempo', '-${b['time_penalty'] ?? 0}'),
            _row('Penalización errores', '-${b['mistake_penalty'] ?? 0}'),
            _row('Penalización pistas', '-${b['hint_penalty'] ?? 0}'),
            const Divider(height: 20),
            Text(changeText, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.list),
                  label: const Text('Niveles'),
                ),
                FilledButton.icon(
                  key: const Key('play_next'),
                  onPressed: onPlayNext,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Siguiente reto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dato resumido (valor grande + etiqueta) que ocupa un tercio del ancho
  Widget _metric(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
