import 'package:flutter/widgets.dart';
// Единственное место, где vysh использует внутренний API xterm2: RenderTerminal
// наружу не экспортируется, а координаты ячеек нужны для выделения пальцем
// и меню. При обновлении xterm2 проверять нужно только этот файл.
// ignore: implementation_imports
import 'package:xterm2/src/ui/render.dart';
import 'package:xterm2/xterm.dart';

/// Геометрия отрисованного терминала: размер ячейки и перевод между
/// координатами экрана и ячейками буфера.
class TerminalGeometry {
  TerminalGeometry._(this._r);

  final RenderTerminal _r;

  /// Геометрия терминала из [key] виджета TerminalView; null - ещё не отрисован.
  static TerminalGeometry? of(GlobalKey<TerminalViewState> key) {
    try {
      final r = key.currentState?.renderTerminal;
      return r == null ? null : TerminalGeometry._(r);
    } catch (_) {
      return null;
    }
  }

  Size get cellSize => _r.cellSize;

  /// Левый верхний угол ячейки в локальных координатах терминала.
  Offset getOffset(CellOffset cell) => _r.getOffset(cell);

  /// Ячейка под точкой в локальных координатах.
  CellOffset getCellOffset(Offset local) => _r.getCellOffset(local);

  Offset globalToLocal(Offset global) => _r.globalToLocal(global);
  Offset localToGlobal(Offset local) => _r.localToGlobal(local);

  /// Выделить символы между двумя точками (локальные координаты).
  void selectCharacters(Offset from, [Offset? to]) => _r.selectCharacters(from, to);
}
