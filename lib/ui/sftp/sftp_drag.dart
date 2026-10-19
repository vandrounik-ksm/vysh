import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../app/sftp/sftp_actions.dart';
import '../../domain/ports/sftp.dart';
import '../../infra/platform/capabilities.dart';

/// Перетаскивание между панелью SFTP и файловым менеджером в обе стороны.
///
/// Наружу:
/// * Windows и macOS - «виртуальный файл»: Проводник или Finder после
///   отпускания сами просят содержимое, vysh скачивает файл (видно в очереди
///   передач) и отдаёт его. Папки так перетащить нельзя - система этого не
///   умеет; для них есть «Скачать».
/// * Linux (GNOME, KDE, Hyprland и любые другие - перетаскивание идёт через
///   GTK, поверх X11 или Wayland) - ссылка на файл: копия начинает скачиваться
///   во временную папку сразу, как только потянули, а получатель забирает её
///   после отпускания. Работает и для папок.
///
/// Внутрь: файлы и папки из любого файлового менеджера загружаются в
/// текущую папку сервера.

/// Метка своих перетаскиваний: строку панели, брошенную обратно в панель,
/// загружать не нужно.
const _localMark = 'vysh-sftp';

/// Формат «любой файл» для виртуальных файлов.
const _anyFile = SimpleFileFormat(
  uniformTypeIdentifiers: ['public.data'],
  mimeTypes: ['application/octet-stream'],
);

/// Можно ли вытащить эту запись наружу на текущей платформе.
bool canDragOut(RemoteEntry e) {
  if (!PlatformCapabilities.fileDragAndDrop) return false;
  if (e.isDir) return !e.isLink && PlatformCapabilities.dragOutFileUri;
  return PlatformCapabilities.dragOutVirtualFiles || PlatformCapabilities.dragOutFileUri;
}

/// Строка панели, которую можно перетащить в файловый менеджер.
class SftpDragSource extends StatelessWidget {
  const SftpDragSource({
    super.key,
    required this.entry,
    required this.actions,
    required this.child,
  });

  final RemoteEntry entry;

  /// null - вкладка не подключена, перетаскивать нечего.
  final SftpActions? Function() actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!canDragOut(entry)) return child;
    return DragItemWidget(
      allowedOperations: () => [DropOperation.copy],
      dragItemProvider: _provide,
      child: DraggableWidget(child: child),
    );
  }

  Future<DragItem?> _provide(DragItemRequest request) async {
    final a = actions();
    if (a == null) return null;
    final item = DragItem(suggestedName: entry.name, localData: _localMark);

    if (PlatformCapabilities.dragOutVirtualFiles && !entry.isDir) {
      item.addVirtualFile(
        format: _anyFile,
        provider: (sinkProvider, progress) => _writeVirtual(a, sinkProvider, progress),
      );
      return item;
    }

    if (PlatformCapabilities.dragOutFileUri) {
      // Скачиваем сразу: получатель ждёт данные после отпускания, и чем
      // меньше осталось докачать, тем меньше шанс, что он не дождётся.
      final download = a.downloadForDrag(entry);
      void onCompleted() {
        final op = request.session.dragCompleted.value;
        if (op == DropOperation.none || op == DropOperation.userCancelled) {
          download.cancel();
        }
      }

      request.session.dragCompleted.addListener(onCompleted);
      item.add(Formats.fileUri.lazy(() async => Uri.file(await download.path)));
      return item;
    }
    return null;
  }

  /// Проводник или Finder попросили содержимое: скачиваем и отдаём потоком.
  Future<void> _writeVirtual(
    SftpActions actions,
    VirtualFileEventSinkProvider sinkProvider,
    WriteProgress progress,
  ) async {
    final download = actions.downloadForDrag(entry);
    progress.onCancel.addListener(download.cancel);
    EventSink? opened;
    try {
      final file = File(await download.path);
      final sink = opened = sinkProvider(fileSize: await file.length());
      await for (final chunk in file.openRead()) {
        sink.add(chunk);
      }
      sink.close();
    } catch (e) {
      final sink = opened ?? sinkProvider(fileSize: 0);
      sink.addError(e);
      sink.close();
    }
  }
}

/// Область панели, принимающая файлы и папки из файлового менеджера.
class SftpDropZone extends StatelessWidget {
  const SftpDropZone({
    super.key,
    required this.enabled,
    required this.onHover,
    required this.onDropPaths,
    required this.child,
  });

  final bool enabled;

  /// true - над панелью тянут файлы (показать подсказку), false - ушли.
  final ValueChanged<bool> onHover;
  final ValueChanged<List<String>> onDropPaths;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.fileDragAndDrop) return child;
    return DropRegion(
      formats: const [Formats.fileUri],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (!enabled) return DropOperation.none;
        final items = event.session.items;
        // Свою же строку обратно в панель не загружаем.
        if (items.any((i) => i.localData == _localMark)) return DropOperation.none;
        if (!items.any((i) => i.canProvide(Formats.fileUri))) return DropOperation.none;
        return event.session.allowedOperations.contains(DropOperation.copy)
            ? DropOperation.copy
            : DropOperation.none;
      },
      onDropEnter: (_) => onHover(true),
      onDropLeave: (_) => onHover(false),
      onDropEnded: (_) => onHover(false),
      onPerformDrop: (event) async {
        final paths = <String>[];
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null || !reader.canProvide(Formats.fileUri)) continue;
          final uri = await _read(reader);
          if (uri != null && uri.isScheme('file')) paths.add(uri.toFilePath());
        }
        if (paths.isNotEmpty) onDropPaths(paths);
      },
      child: child,
    );
  }

  static Future<Uri?> _read(DataReader reader) {
    final c = Completer<Uri?>();
    final started = reader.getValue<Uri>(
      Formats.fileUri,
      (value) {
        if (!c.isCompleted) c.complete(value);
      },
      onError: (_) {
        if (!c.isCompleted) c.complete(null);
      },
    );
    if (started == null && !c.isCompleted) c.complete(null);
    return c.future;
  }
}
