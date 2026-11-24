import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../levels/domain/entities/level.dart';
import '../../domain/entities/game_entities.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/services/zip_rules.dart';

enum GameStatus { idle, loading, playing, submitting, completed, error }

/// Controlador de la partida: camino actual, siguiente checkpoint, cronómetro,
/// errores, pistas y estado de finalización.
///
/// La página sólo dibuja este estado; toda la lógica vive aquí y en [ZipRules].
class GameController extends ChangeNotifier {
  GameController(this._repository);

  final GameRepository _repository;

  GameStatus status = GameStatus.idle;
  Level? level;
  ZipRules? rules;
  GameSession? session;
  GameResult? result;

  final List<int> path = [];
  final List<MoveRecord> moves = [];

  int mistakes = 0;
  int hintsUsed = 0;
  int? hintCell;
  int? invalidCell;
  String? message;

  /// true si [message] describe un error (se muestra en rojo hasta que cambie)
  bool messageIsError = false;
  String? error;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _flashTimer;
  int? _lastInvalidDragCell;
  bool _disposed = false;

  // ---------- Lectura de estado ----------
  Duration get elapsed => _stopwatch.elapsed;
  int get totalCells => level?.totalCells ?? 36;
  int get progress => path.length;
  int get nextCheckpoint => rules?.nextCheckpoint(path) ?? 1;
  bool get isPlaying => status == GameStatus.playing;
  bool get isComplete => rules != null && rules!.isComplete(path);

  // ---------- Ciclo de vida ----------
  Future<void> start({int? levelId}) async {
    status = GameStatus.loading;
    error = null;
    _notify();
    try {
      final started = await _repository.startGame(levelId: levelId);
      _setup(started.session, started.level);
    } on ApiException catch (e) {
      error = e.message;
      status = GameStatus.error;
      _notify();
    }
  }

  void _setup(GameSession newSession, Level newLevel) {
    session = newSession;
    level = newLevel;
    rules = ZipRules(size: newLevel.size, checkpoints: newLevel.checkpoints);
    path.clear();
    moves.clear();
    mistakes = 0;
    hintsUsed = 0;
    hintCell = null;
    invalidCell = null;
    result = null;
    _setMessage('Empieza en el número 1');
    status = GameStatus.playing;
    _stopwatch
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    _notify();
  }

  // ---------- Interacción ----------

  /// Clic / toque sobre una celda.
  /// - Celda nueva: intenta avanzar (si es inválida cuenta como error).
  /// - Celda ya recorrida: recorta el camino hasta esa celda.
  void tapCell(int cell) {
    if (!isPlaying) return;
    if (path.isNotEmpty && cell == path.last) return;
    if (path.contains(cell)) {
      _truncateTo(cell);
      return;
    }
    _tryAdd(cell);
  }

  /// Arrastre (mouse o dedo) que entra a una celda.
  void dragToCell(int cell) {
    if (!isPlaying) return;
    if (path.isNotEmpty && cell == path.last) return;
    if (path.length >= 2 && cell == path[path.length - 2]) {
      undo();
      return;
    }
    if (path.contains(cell)) return;
    if (path.isNotEmpty && !rules!.areAdjacent(path.last, cell)) return;
    if (_lastInvalidDragCell == cell) return;
    _tryAdd(cell, fromDrag: true);
  }

  void endDrag() => _lastInvalidDragCell = null;

  /// Movimiento con teclado (flechas o WASD) desde la última celda del camino.
  /// - Camino vacío: cualquier dirección coloca el inicio en el número 1.
  /// - Hacia la celda anterior: deshace (igual que al arrastrar hacia atrás).
  /// - Fuera del tablero: se ignora y no cuenta como error.
  /// - Cualquier otro movimiento pasa por las mismas reglas que un clic.
  void moveBy(int dRow, int dCol) {
    if (!isPlaying) return;
    final r = rules!;
    if (path.isEmpty) {
      _tryAdd(r.checkpoints.first);
      return;
    }
    final row = path.last ~/ r.size + dRow;
    final col = path.last % r.size + dCol;
    if (row < 0 || row >= r.size || col < 0 || col >= r.size) return;

    final target = row * r.size + col;
    if (path.length >= 2 && target == path[path.length - 2]) {
      undo();
      return;
    }
    _tryAdd(target);
  }

  void undo() {
    if (!isPlaying || path.isEmpty) return;
    final removed = path.removeLast();
    _record(MoveType.undo, removed);
    _setMessage(null);
    _notify();
  }

  void restart() {
    if (!isPlaying) return;
    path.clear();
    hintCell = null;
    _record(MoveType.restart, null);
    _setMessage('Nivel reiniciado. Empieza en el número 1');
    _notify();
  }

  Future<void> requestHint() async {
    if (!isPlaying || session == null) return;
    try {
      final hint = await _repository.requestHint(session!.id, List.of(path));
      hintsUsed = hint.hintsUsed;
      hintCell = hint.nextCell;
      _setMessage(
        hint.type == HintType.backtrack
            ? 'Este camino no tiene salida: deshaz ${hint.undoSteps} paso(s) y sigue por la celda marcada'
            : 'Pista: continúa por la celda marcada',
      );
    } on ApiException catch (e) {
      _setMessage(e.message, isError: true);
    }
    _notify();
  }

  Future<void> submit() async {
    if (session == null || !isComplete) return;
    status = GameStatus.submitting;
    _setMessage('Validando con el servidor...');
    _notify();
    try {
      result = await _repository.finishGame(session!.id, List.of(path), List.of(moves));
      status = GameStatus.completed;
      _setMessage('¡Puzzle resuelto!');
      _stopwatch.stop();
      _ticker?.cancel();
    } on ApiException catch (e) {
      // El servidor rechazó la solución (422) o ya estaba terminada (409)
      status = e.isConflict ? GameStatus.completed : GameStatus.playing;
      _setMessage(e.message, isError: true);
    }
    _notify();
  }

  // ---------- Internos ----------
  void _tryAdd(int cell, {bool fromDrag = false}) {
    final check = rules!.canMove(path, cell);
    if (check.valid) {
      path.add(cell);
      _record(MoveType.add, cell);
      hintCell = null; // la pista se consume al moverse
      invalidCell = null;
      _lastInvalidDragCell = null;
      _setMessage(null);
      _notify();
      if (isComplete) submit();
      return;
    }

    mistakes++;
    _record(MoveType.invalid, cell);
    invalidCell = cell;
    if (fromDrag) _lastInvalidDragCell = cell;
    _setMessage(ZipRules.describe(check.error!), isError: true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      invalidCell = null;
      _notify();
    });
    _notify();
  }

  void _truncateTo(int cell) {
    final index = path.indexOf(cell);
    while (path.length > index + 1) {
      _record(MoveType.undo, path.removeLast());
    }
    _setMessage(null);
    _notify();
  }

  void _setMessage(String? text, {bool isError = false}) {
    message = text;
    messageIsError = text != null && isError;
  }

  void _record(MoveType type, int? cell) {
    moves.add(MoveRecord(type: type, cell: cell, elapsedMs: _stopwatch.elapsedMilliseconds));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _flashTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
