import 'package:flutter/material.dart';

import '../../domain/ports/sftp.dart';
import '../../l10n/app_strings.dart';

/// Строки списка панели файлов: запись папки и заглушка пустого состояния.

class SftpPlaceholder extends StatelessWidget {
  const SftpPlaceholder({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: scheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class SftpEntryRow extends StatelessWidget {
  const SftpEntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondary,
    required this.strings,
  });

  /// null - строка «..».
  final RemoteEntry? entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset globalPosition) onSecondary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;
    final dim = scheme.onSurfaceVariant;

    final icon = e == null
        ? Icons.subdirectory_arrow_left
        : e.isDir
            ? (e.isLink ? Icons.folder_special_outlined : Icons.folder_rounded)
            : (e.isLink ? Icons.link : _fileIcon(e.name));
    final iconColor = e == null || e.isDir ? scheme.primary : dim;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onSecondaryTapUp: (d) => onSecondary(d.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e?.name ?? '..',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: e != null && e.isHidden ? dim : scheme.onSurface,
                    ),
                  ),
                ),
                if (e != null) ...[
                  if (!e.isDir)
                    SizedBox(
                      width: 72,
                      child: Text(strings.bytes(e.size),
                          textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: dim)),
                    ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: e.permissions,
                    child: SizedBox(
                      width: 96,
                      child: Text(
                        _date(e.modified, strings),
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12, color: dim),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _date(DateTime? d, AppStrings strings) {
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return strings.todayAt('${_two(d.hour)}:${_two(d.minute)}');
    }
    return '${_two(d.day)}.${_two(d.month)}.${d.year % 100} ${_two(d.hour)}:${_two(d.minute)}';
  }

  static IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'sh' || 'bash' || 'zsh' || 'py' || 'js' || 'ts' || 'go' || 'rs' || 'c' || 'cpp' || 'h' ||
      'java' || 'php' || 'rb' || 'pl' || 'lua' => Icons.code,
      'conf' || 'cfg' || 'ini' || 'yaml' || 'yml' || 'toml' || 'json' || 'xml' || 'env' =>
        Icons.settings_outlined,
      'log' || 'txt' || 'md' => Icons.description_outlined,
      'zip' || 'gz' || 'tgz' || 'xz' || 'bz2' || 'zst' || '7z' || 'rar' || 'tar' || 'deb' ||
      'rpm' || 'ipk' => Icons.inventory_2_outlined,
      'iso' || 'img' || 'qcow2' || 'vmdk' => Icons.album_outlined,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' || 'webp' => Icons.image_outlined,
      'pem' || 'crt' || 'key' || 'pub' => Icons.key_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}
