import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/game_controller.dart';
import '../widgets/game_hud.dart';
import '../widgets/result_summary.dart';
import '../widgets/zip_board.dart';

/// Pantalla de juego. Si [levelId] es null el backend elige el nivel
/// según la dificultad adaptativa del jugador.
///
/// Controles: clic/arrastre, toque/deslizar, y teclado (flechas o WASD para
/// moverse; Retroceso o Z para deshacer). La página sólo traduce cada tecla a
/// una llamada del [GameController]; las reglas viven en el controlador.
class GamePage extends StatefulWidget {
  const GamePage({super.key, this.levelId});

  final int? levelId;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameController? _controller;
  Object? _reportedResult;

  /// Dirección (fila, columna) de cada tecla de movimiento
  static final Map<LogicalKeyboardKey, (int, int)> _directions = {
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.keyW: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.keyS: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.keyA: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
    LogicalKeyboardKey.keyD: (0, 1),
  };

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = GameController(AppScope.of(context).gameRepository);
      _controller!.addListener(_onChange);
      _controller!.start(levelId: widget.levelId);
    }
  }

  void _onChange() {
    final result = _controller!.result;
    // Actualiza (una sola vez) la dificultad recomendada del usuario al terminar
    if (result != null && !identical(result, _reportedResult)) {
      _reportedResult = result;
      AppScope.of(context).authController.updateRecommendedDifficulty(result.recommendedDifficulty);
    }
  }

  /// Teclado. Sólo actúa si esta pantalla es la visible (no con un diálogo encima).
  /// Devuelve true cuando consume la tecla, así las flechas no desplazan la página.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final c = _controller;
    if (c == null || !c.isPlaying) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;

    final key = event.logicalKey;
    final direction = _directions[key];
    if (direction != null) {
      c.moveBy(direction.$1, direction.$2);
      return true;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.keyZ) {
      c.undo();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller?.removeListener(_onChange);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final level = controller.level;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              level == null ? 'ZIP Game' : '${level.name} · ${difficultyLabel(level.difficulty)}',
            ),
          ),
          body: SafeArea(child: _body(context, controller)),
        );
      },
    );
  }

  Widget _body(BuildContext context, GameController c) {
    switch (c.status) {
      case GameStatus.idle:
      case GameStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case GameStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 8),
                Text(c.error ?? 'Error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => c.start(levelId: widget.levelId),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      default:
        break;
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Horizontal (PC / tablet acostada): tablero a la izquierda y panel a la derecha
        final wide = box.maxWidth >= 840 && box.maxWidth > box.maxHeight * 1.15;
        return wide ? _wideLayout(c, box) : _narrowLayout(c, box);
      },
    );
  }

  /// PC: el tablero usa todo el alto disponible y nada queda fuera de la pantalla.
  Widget _wideLayout(GameController c, BoxConstraints box) {
    const panelWidth = 380.0;
    final side = math.min(math.min(box.maxHeight - 32, box.maxWidth - panelWidth - 80), 640.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: side,
              child: ZipBoard(controller: c, maxSide: side),
            ),
            const SizedBox(width: 32),
            SizedBox(
              width: panelWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: side),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GameHud(controller: c),
                      const SizedBox(height: 12),
                      ..._controls(c),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Celular o ventana angosta: columna; el tablero se ajusta al alto que queda.
  Widget _narrowLayout(GameController c, BoxConstraints box) {
    final hudHeight = box.maxWidth - 32 >= 480 ? 60.0 : 106.0;
    final side = (box.maxHeight - hudHeight - 190).clamp(260.0, 600.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              GameHud(controller: c),
              const SizedBox(height: 12),
              ZipBoard(controller: c, maxSide: side),
              const SizedBox(height: 8),
              ..._controls(c),
            ],
          ),
        ),
      ),
    );
  }

  /// Mensaje + botones (o el resumen al terminar). Se usa en ambos diseños.
  List<Widget> _controls(GameController c) {
    final scheme = Theme.of(context).colorScheme;
    final busy = c.status == GameStatus.submitting;
    final finished = c.status == GameStatus.completed && c.result != null;

    return [
      // Altura fija: que aparezca o desaparezca el mensaje no mueve los botones.
      // Al terminar no se muestra: la tarjeta de resultado ya lo dice.
      if (!finished) ...[
        SizedBox(
          height: 44,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: c.message == null
                  ? const SizedBox.shrink()
                  : Text(
                      c.message!,
                      key: ValueKey('${c.messageIsError}${c.message}'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.messageIsError ? scheme.error : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
      if (finished)
        ResultSummary(
          result: c.result!,
          onBack: () => Navigator.of(context).pop(),
          onPlayNext: () => c.start(),
        )
      else ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('btn_undo'),
              onPressed: busy || c.path.isEmpty ? null : c.undo,
              icon: const Icon(Icons.undo),
              label: const Text('Deshacer'),
            ),
            OutlinedButton.icon(
              key: const Key('btn_restart'),
              onPressed: busy ? null : c.restart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reiniciar'),
            ),
            FilledButton.tonalIcon(
              key: const Key('btn_hint'),
              onPressed: busy ? null : c.requestHint,
              icon: const Icon(Icons.lightbulb),
              label: const Text('Pista'),
            ),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
          ],
        ),
        if (_hasKeyboard) ...[const SizedBox(height: 16), const _KeyboardHelp()],
      ],
    ];
  }

  /// En web y escritorio se muestra la ayuda de teclado; en Android/iOS no.
  bool get _hasKeyboard =>
      kIsWeb ||
      const {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
}

/// Recuadro con los atajos de teclado.
class _KeyboardHelp extends StatelessWidget {
  const _KeyboardHelp();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget key(String label) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(label, style: small?.copyWith(fontWeight: FontWeight.bold)),
    );

    return Container(
      key: const Key('keyboard_help'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Teclado', style: small?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              key('←'),
              key('↑'),
              key('↓'),
              key('→'),
              Text(' o ', style: small),
              key('W'),
              key('A'),
              key('S'),
              key('D'),
              Text('  moverte', style: small),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              key('Retroceso'),
              Text(' o ', style: small),
              key('Z'),
              Text('  deshacer', style: small),
            ],
          ),
        ],
      ),
    );
  }
}
