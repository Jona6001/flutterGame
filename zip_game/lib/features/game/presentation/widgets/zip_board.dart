import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../controllers/game_controller.dart';

/// Tablero interactivo 6x6.
///  - Mouse (Chrome): clic o arrastrar con el botón presionado.
///  - Táctil (móvil): tocar o deslizar el dedo.
///  - Teclado: flechas o WASD (los maneja GamePage).
///
/// Ocupa el mayor cuadrado que cabe en el espacio disponible (máx. [maxSide]).
/// Los colores salen del ColorScheme, así se ve bien en tema claro y oscuro.
class ZipBoard extends StatelessWidget {
  const ZipBoard({super.key, required this.controller, this.maxSide = 600});

  final GameController controller;
  final double maxSide;

  @override
  Widget build(BuildContext context) {
    final rules = controller.rules!;
    final size = rules.size;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final complete = controller.isComplete;
    final success = dark ? Colors.green.shade400 : Colors.green.shade600;
    final head = controller.path.isEmpty ? null : controller.path.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        var side = math.min(constraints.maxWidth, maxSide);
        if (constraints.maxHeight.isFinite) side = math.min(side, constraints.maxHeight);
        final cell = side / size;

        int? cellAt(Offset p) {
          if (p.dx < 0 || p.dy < 0 || p.dx >= side || p.dy >= side) return null;
          return (p.dy ~/ cell) * size + (p.dx ~/ cell);
        }

        return Center(
          child: SizedBox(
            key: const Key('zip_board'),
            width: side,
            height: side,
            child: GestureDetector(
              onTapUp: (d) {
                final c = cellAt(d.localPosition);
                if (c != null) controller.tapCell(c);
              },
              onPanStart: (d) {
                final c = cellAt(d.localPosition);
                if (c != null) controller.dragToCell(c);
              },
              onPanUpdate: (d) {
                final c = cellAt(d.localPosition);
                if (c != null) controller.dragToCell(c);
              },
              onPanEnd: (_) => controller.endDrag(),
              child: Stack(
                children: [
                  // 1) Celdas
                  for (var i = 0; i < size * size; i++)
                    Positioned(
                      left: (i % size) * cell,
                      top: (i ~/ size) * cell,
                      width: cell,
                      height: cell,
                      child: _Cell(
                        key: Key('cell_$i'),
                        visited: controller.path.contains(i),
                        invalid: controller.invalidCell == i,
                        hinted: controller.hintCell == i,
                        isHead: head == i && !complete,
                        completed: complete,
                        success: success,
                        scheme: scheme,
                        dark: dark,
                      ),
                    ),
                  // 2) Línea del camino
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size(side, side),
                      painter: _PathPainter(
                        path: List.of(controller.path),
                        size: size,
                        color: complete ? success : scheme.primary,
                      ),
                    ),
                  ),
                  // 3) Números (checkpoints)
                  for (var n = 0; n < rules.checkpoints.length; n++)
                    Positioned(
                      left: (rules.checkpoints[n] % size) * cell + cell * 0.2,
                      top: (rules.checkpoints[n] ~/ size) * cell + cell * 0.2,
                      width: cell * 0.6,
                      height: cell * 0.6,
                      child: IgnorePointer(
                        child: _Checkpoint(
                          key: Key('checkpoint_${n + 1}'),
                          number: n + 1,
                          reached: n + 1 < controller.nextCheckpoint,
                          isNext: n + 1 == controller.nextCheckpoint && !complete,
                          completed: complete,
                          success: success,
                          scheme: scheme,
                          fontSize: cell * 0.26,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.visited,
    required this.invalid,
    required this.hinted,
    required this.isHead,
    required this.completed,
    required this.success,
    required this.scheme,
    required this.dark,
  });

  final bool visited;
  final bool invalid;
  final bool hinted;
  final bool isHead;
  final bool completed;
  final Color success;
  final ColorScheme scheme;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    Color color = scheme.surfaceContainerHighest;
    if (visited) {
      color = completed ? success.withValues(alpha: dark ? 0.28 : 0.22) : scheme.primaryContainer;
    }
    if (invalid) color = scheme.error.withValues(alpha: dark ? 0.75 : 0.6);

    // Prioridad del borde: pista > celda actual (punta del camino)
    final Border? border = hinted
        ? Border.all(color: Colors.amber.shade600, width: 4)
        : isHead
        ? Border.all(color: scheme.primary, width: 3)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
    );
  }
}

/// Círculo con el número. Pendiente: color "inverso" al fondo (alto contraste
/// en claro y oscuro). Alcanzado: color primario. Siguiente: anillo resaltado.
class _Checkpoint extends StatelessWidget {
  const _Checkpoint({
    super.key,
    required this.number,
    required this.reached,
    required this.isNext,
    required this.completed,
    required this.success,
    required this.scheme,
    required this.fontSize,
  });

  final int number;
  final bool reached;
  final bool isNext;
  final bool completed;
  final Color success;
  final ColorScheme scheme;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (completed) {
      background = success;
      foreground = Colors.white;
    } else if (reached) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.inverseSurface;
      foreground = scheme.onInverseSurface;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: isNext ? Border.all(color: scheme.tertiary, width: 3) : null,
        boxShadow: isNext
            ? [BoxShadow(color: scheme.tertiary.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
      child: Text(
        '$number',
        style: TextStyle(color: foreground, fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.path, required this.size, required this.color});

  final List<int> path;
  final int size;
  final Color color;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (path.isEmpty) return;
    final cell = canvasSize.width / size;
    Offset center(int i) => Offset((i % size + 0.5) * cell, (i ~/ size + 0.5) * cell);

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = cell * 0.32
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final line = Path()..moveTo(center(path.first).dx, center(path.first).dy);
    for (final i in path.skip(1)) {
      line.lineTo(center(i).dx, center(i).dy);
    }
    canvas.drawPath(line, paint);
    canvas.drawCircle(center(path.last), cell * 0.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.path.length != path.length || old.color != color || !_same(old.path, path);

  bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
