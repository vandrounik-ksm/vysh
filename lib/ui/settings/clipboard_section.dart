import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/app_strings.dart';
import '../../domain/services/settings_controller.dart';
import '../../infra/platform/desktop_env.dart';
import 'setting_row.dart';

/// Буфер обмена в терминале: стиль (две карточки) и пара переключателей.
class ClipboardSection extends ConsumerWidget {
  const ClipboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final ru = AppStrings.of(context, s.language).isRu;
    final linux = s.copyOnSelect;
    final rmbPaste = s.rightClick != RightClickAction.menu;

    final confirm = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(ru ? 'Спрашивать перед вставкой нескольких строк' : 'Confirm multi-line paste'),
      value: s.confirmMultilinePaste,
      onChanged: ctrl.setConfirmMultilinePaste,
    );

    // На телефоне мыши нет: копирование и вставка идут через меню выделения.
    if (DesktopEnv.isMobile) return confirm;

    // Галочка «правый клик» внутри карточки относится к её стилю.
    // Клик по галочке в невыбранной карточке заодно выбирает её.
    void setRmb(bool linuxCard, bool on) {
      if (linux != linuxCard) ctrl.setLinuxClipboard(linuxCard);
      ctrl.setRightClickPaste(on);
    }

    final cards = [
      _StyleCard(
        selected: linux,
        icon: Icons.mouse_outlined,
        title: ru ? 'Как в Linux' : 'Linux style',
        copyKeys: [ru ? 'Выделение' : 'Selection'],
        pasteKeys: [ru ? 'Средняя кнопка' : 'Middle click', if (linux && rmbPaste) ru ? 'ПКМ' : 'RMB'],
        rmbLabel: ru ? 'ПКМ тоже вставляет' : 'Right click pastes too',
        rmbValue: linux && rmbPaste,
        onRmb: (v) => setRmb(true, v),
        onTap: () => ctrl.setLinuxClipboard(true),
        copyTooltip: AppStrings.of(context, s.language).copy,
        pasteTooltip: AppStrings.of(context, s.language).paste,
      ),
      _StyleCard(
        selected: !linux,
        icon: Icons.keyboard_outlined,
        title: ru ? 'Клавишами' : 'Keyboard',
        copyKeys: ['Ctrl', 'Shift', 'C', if (!linux && rmbPaste) ru ? 'ПКМ' : 'RMB'],
        pasteKeys: ['Ctrl', 'Shift', 'V', if (!linux && rmbPaste) ru ? 'ПКМ' : 'RMB'],
        rmbLabel: ru ? 'ПКМ копирует и вставляет' : 'Right click copies and pastes',
        rmbValue: !linux && rmbPaste,
        onRmb: (v) => setRmb(false, v),
        onTap: () => ctrl.setLinuxClipboard(false),
        copyTooltip: AppStrings.of(context, s.language).copy,
        pasteTooltip: AppStrings.of(context, s.language).paste,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          label: ru ? 'Буфер обмена' : 'Clipboard',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 420
                  ? Column(children: [cards[0], const SizedBox(height: 8), cards[1]])
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[1]),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(ru ? 'Ctrl+V тоже вставляет' : 'Ctrl+V pastes too'),
          value: s.ctrlVPaste,
          onChanged: ctrl.setCtrlVPaste,
        ),
        confirm,
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.copyKeys,
    required this.pasteKeys,
    required this.rmbLabel,
    required this.rmbValue,
    required this.onRmb,
    required this.onTap,
    required this.copyTooltip,
    required this.pasteTooltip,
  });

  final String copyTooltip;
  final String pasteTooltip;
  final bool selected;
  final IconData icon;
  final String title;
  final List<String> copyKeys;
  final List<String> pasteKeys;
  final String rmbLabel;
  final bool rmbValue;
  final ValueChanged<bool> onRmb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final muted = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: selected
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: selected ? scheme.primary : muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _KeyRow(icon: Icons.content_copy, tooltip: copyTooltip, keys: copyKeys, muted: muted),
              const SizedBox(height: 6),
              _KeyRow(icon: Icons.content_paste, tooltip: pasteTooltip, keys: pasteKeys, muted: muted),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onRmb(!rmbValue),
                child: Row(
                  children: [
                    Checkbox(
                      value: rmbValue,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => onRmb(v ?? false),
                    ),
                    Expanded(
                      child: Text(rmbLabel, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Значок действия и его клавиши.
class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.icon,
    required this.tooltip,
    required this.keys,
    required this.muted,
  });

  final IconData icon;
  final String tooltip;
  final List<String> keys;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Tooltip(message: tooltip, child: Icon(icon, size: 16, color: muted)),
        const SizedBox(width: 10),
        Flexible(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final k in keys)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(k, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
