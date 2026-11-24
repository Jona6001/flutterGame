import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../controllers/game_controller.dart';

/// Barra de información: cronómetro, progreso, siguiente número, errores y pistas.
///
/// La distribución es FIJA (5 en una fila, o 3 + 2 si el ancho no alcanza) y cada
/// dato ocupa la misma fracción del ancho. Así, aunque cambie el texto (00:09 → 00:10,
/// 9/36 → 10/36) la barra no salta de renglón ni mueve el tablero.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final rules = controller.rules!;
    final next = controller.nextCheckpoint;
    final nextLabel = next > rules.lastNumber ? '✓' : '$next';

    final stats = <Widget>[
      _Stat(
        key: const Key('hud_timer'),
        icon: Icons.timer_outlined,
        label: formatDuration(controller.elapsed.inSeconds),
      ),
      _Stat(
        key: const Key('hud_progress'),
        icon: Icons.grid_on,
        label: '${controller.progress}/${controller.totalCells}',
      ),
      _Stat(key: const Key('hud_next'), icon: Icons.flag_outlined, label: 'Sig: $nextLabel'),
      _Stat(
        key: const Key('hud_mistakes'),
        icon: Icons.close,
        label: 'Errores: ${controller.mistakes}',
        highlight: controller.mistakes > 0,
      ),
      _Stat(
        key: const Key('hud_hints'),
        icon: Icons.lightbulb_outline,
        label: 'Pistas: ${controller.hintsUsed}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final oneRow = constraints.maxWidth >= 480;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (oneRow)
              _row(stats)
            else ...[
              _row(stats.sublist(0, 3)),
              const SizedBox(height: 6),
              _row(stats.sublist(3)),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: controller.progress / controller.totalCells,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(List<Widget> items) => Row(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: items[i]),
      ],
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.icon, required this.label, this.highlight = false});

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.error : scheme.onSurfaceVariant;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      // scaleDown: en pantallas muy angostas el texto se reduce en vez de cortarse
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: highlight ? scheme.error : scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
