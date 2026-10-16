import 'dart:typed_data';

/// Читает кусок файла шрифта: [length] байт с [offset]. Короче - значит,
/// файл кончился.
typedef FontByteReader = Uint8List Function(int offset, int length);

/// Почему файл не добавлен.
enum AddFontError { tooLarge, notFont, copyFailed }

class AddFontException implements Exception {
  const AddFontException(this.error, [this.detail = '']);

  final AddFontError error;
  final String detail;

  @override
  String toString() => 'AddFontException($error, $detail)';
}

/// Что vysh нужно знать о шрифте: имя семейства и моноширинный ли он.
class FontInfo {
  const FontInfo({required this.family, required this.monospace});

  /// Имя семейства, по которому шрифт находит система (typographic family,
  /// а если его нет, обычное). Одно на все начертания.
  final String family;

  /// Буквы одной ширины (допускаются двойные, как у CJK и значков).
  final bool monospace;

  @override
  String toString() => 'FontInfo($family, mono: $monospace)';
}

/// Разбор заголовков TTF / OTF / TTC без сторонних библиотек.
///
/// Читаются только нужные таблицы (`name`, `post`, `OS/2`, `hhea`, `hmtx`,
/// `cmap`), поэтому даже большие CJK-шрифты разбираются быстро. Битый или
/// чужой файл даёт пустой список, а не исключение.
abstract final class FontInfoParser {
  /// Все начертания файла (у TTC их несколько). Символьные шрифты (Wingdings
  /// и подобные) пропускаются: букв в них нет.
  static List<FontInfo> parse(FontByteReader read) {
    try {
      final head = _Bytes(read(0, 12));
      if (head.length < 12) return const [];
      final tag = head.u32(0);
      if (tag == _ttcf) {
        final count = head.u32(8).clamp(0, 64).toInt();
        final offsets = _Bytes(read(12, count * 4));
        return [
          for (var i = 0; i < count && (i + 1) * 4 <= offsets.length; i++)
            ?_face(read, offsets.u32(i * 4)),
        ];
      }
      final one = _face(read, 0);
      return one == null ? const [] : [one];
    } catch (_) {
      return const [];
    }
  }

  static const _ttcf = 0x74746366; // 'ttcf'
  static const _otto = 0x4F54544F; // 'OTTO'
  static const _true = 0x74727565; // 'true'

  /// Одно начертание; битое - null, остальные начертания TTC это не задевает.
  static FontInfo? _face(FontByteReader read, int base) {
    try {
      return _faceAt(read, base);
    } catch (_) {
      return null;
    }
  }

  static FontInfo? _faceAt(FontByteReader read, int base) {
    final dir = _Bytes(read(base, 12));
    if (dir.length < 12) return null;
    final version = dir.u32(0);
    if (version != 0x00010000 && version != _otto && version != _true) return null;
    final numTables = dir.u16(4).clamp(0, 512).toInt();
    final records = _Bytes(read(base + 12, numTables * 16));
    final tables = <String, (int, int)>{};
    for (var i = 0; i < numTables && (i + 1) * 16 <= records.length; i++) {
      final r = i * 16;
      tables[String.fromCharCodes(records.bytes, r, r + 4)] =
          (records.u32(r + 8), records.u32(r + 12));
    }

    Uint8List? table(String name, [int max = 1 << 20]) {
      final t = tables[name];
      if (t == null) return null;
      return read(t.$1, t.$2 < max ? t.$2 : max);
    }

    final nameTable = table('name');
    if (nameTable == null) return null;
    final family = _family(_Bytes(nameTable));
    if (family == null || family.isEmpty || family.startsWith('@')) return null;

    final cmap = table('cmap', 4 + 8 * 64);
    if (cmap != null && _symbolOnly(_Bytes(cmap))) return null;

    return FontInfo(family: family, monospace: _monospace(table));
  }

  /// nameID 16 (typographic family), иначе 1. Сначала английское имя
  /// Windows-записи, потом любое Unicode, потом Mac Roman.
  static String? _family(_Bytes t) {
    if (t.length < 6) return null;
    final count = t.u16(2);
    final strings = t.u16(4);
    String? best;
    var bestScore = -1;
    for (var i = 0; i < count; i++) {
      final r = 6 + i * 12;
      if (r + 12 > t.length) break;
      final platform = t.u16(r);
      final encoding = t.u16(r + 2);
      final language = t.u16(r + 4);
      final nameId = t.u16(r + 6);
      if (nameId != 1 && nameId != 16) continue;
      final len = t.u16(r + 8);
      final off = strings + t.u16(r + 10);
      if (off + len > t.length || len == 0) continue;

      String? text;
      var score = nameId == 16 ? 100 : 0;
      if (platform == 3 && (encoding == 1 || encoding == 10)) {
        text = _utf16be(t.bytes, off, len);
        score += language == 0x409 ? 30 : 20;
      } else if (platform == 0) {
        text = _utf16be(t.bytes, off, len);
        score += 15;
      } else if (platform == 1 && encoding == 0) {
        text = String.fromCharCodes(t.bytes, off, off + len);
        score += language == 0 ? 10 : 5;
      }
      if (text == null) continue;
      text = text.replaceAll('\u0000', '').trim();
      if (text.isEmpty) continue;
      if (score > bestScore) {
        bestScore = score;
        best = text;
      }
    }
    return best;
  }

  static String _utf16be(Uint8List b, int off, int len) {
    final units = <int>[];
    for (var i = off; i + 1 < off + len; i += 2) {
      units.add((b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  /// Только символьная кодировка (3, 0) и ни одной Unicode-таблицы.
  static bool _symbolOnly(_Bytes t) {
    if (t.length < 4) return false;
    final n = t.u16(2);
    var symbol = false;
    for (var i = 0; i < n; i++) {
      final r = 4 + i * 8;
      if (r + 4 > t.length) break;
      final platform = t.u16(r);
      final encoding = t.u16(r + 2);
      if (platform == 0) return false;
      if (platform == 3 && encoding == 0) symbol = true;
      if (platform == 3 && (encoding == 1 || encoding == 10)) return false;
    }
    return symbol;
  }

  /// Латинские буквы и цифры: по ним и судим о моноширинности.
  static final _probe = [
    for (var c = 0x30; c <= 0x39; c++) c,
    for (var c = 0x41; c <= 0x5A; c++) c,
    for (var c = 0x61; c <= 0x7A; c++) c,
  ];

  static bool _monospace(Uint8List? Function(String name, [int max]) table) {
    // Главное - измерить: ширины латинских букв и цифр через cmap и hmtx.
    // Так моноширинными оказываются и CJK-шрифты с полуширинной латиницей,
    // и Nerd Font без Mono в имени, а пропорциональная латиница в «готических»
    // японских шрифтах и эмодзи без букв - нет.
    final measured = _probeWidths(table);
    if (measured != null) {
      // Без латиницы (эмодзи, значки) для терминала шрифт не годится.
      return measured.length >= _probe.length ~/ 2 && measured.toSet().length == 1;
    }

    // Не вышло (нестандартный cmap) - верим флагам шрифта.
    final post = table('post', 16);
    if (post != null && post.length >= 16 && _Bytes(post).u32(12) != 0) return true;
    final os2 = table('OS/2', 48);
    if (os2 != null && os2.length >= 42) {
      final b = _Bytes(os2);
      if (b.u8(32) == 2 && b.u8(35) == 9) return true;
    }
    final hhea = table('hhea', 36);
    if (hhea == null || hhea.length < 36) return false;
    final metrics = _Bytes(hhea).u16(34);
    if (metrics <= 1) return metrics == 1;
    final hmtx = table('hmtx', metrics * 4);
    if (hmtx == null) return false;
    return widthsLookMonospace([
      for (var i = 0; i + 1 < hmtx.length && i < metrics * 4; i += 4)
        (hmtx[i] << 8) | hmtx[i + 1],
    ]);
  }

  /// Ширины найденных глифов [_probe]; null - cmap или hmtx не прочитать.
  static List<int>? _probeWidths(Uint8List? Function(String name, [int max]) table) {
    final cmapBytes = table('cmap', 8 << 20);
    final hhea = table('hhea', 36);
    if (cmapBytes == null || hhea == null || hhea.length < 36) return null;
    final metrics = _Bytes(hhea).u16(34);
    if (metrics == 0) return null;
    final hmtx = table('hmtx', metrics * 4);
    if (hmtx == null || hmtx.length < 4) return null;
    final h = _Bytes(hmtx);
    final lastMetric = (h.length ~/ 4 < metrics ? h.length ~/ 4 : metrics) - 1;

    final glyphOf = _cmapLookup(_Bytes(cmapBytes));
    if (glyphOf == null) return null;
    final widths = <int>[];
    for (final c in _probe) {
      final g = glyphOf(c);
      if (g <= 0) continue;
      final i = g <= lastMetric ? g : lastMetric;
      final w = h.u16(i * 4);
      if (w > 0) widths.add(w);
    }
    return widths;
  }

  /// Функция «код символа → глиф» по лучшей Unicode-таблице cmap
  /// (формат 12 или 4).
  static int Function(int)? _cmapLookup(_Bytes t) {
    if (t.length < 4) return null;
    final n = t.u16(2);
    int? best;
    var bestScore = -1;
    for (var i = 0; i < n; i++) {
      final r = 4 + i * 8;
      if (r + 8 > t.length) break;
      final platform = t.u16(r);
      final encoding = t.u16(r + 2);
      final off = t.u32(r + 4);
      if (off + 2 > t.length) continue;
      final format = t.u16(off);
      if (format != 4 && format != 12) continue;
      final unicode = platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      if (!unicode) continue;
      final score = format == 12 ? 2 : 1;
      if (score > bestScore) {
        bestScore = score;
        best = off;
      }
    }
    if (best == null) return null;
    final o = best;
    if (t.u16(o) == 12) {
      if (o + 16 > t.length) return null;
      final groups = t.u32(o + 12);
      return (c) {
        for (var i = 0; i < groups; i++) {
          final g = o + 16 + i * 12;
          if (g + 12 > t.length) break;
          final start = t.u32(g);
          final end = t.u32(g + 4);
          if (c >= start && c <= end) return t.u32(g + 8) + (c - start);
        }
        return 0;
      };
    }
    if (o + 14 > t.length) return null;
    final segX2 = t.u16(o + 6);
    final ends = o + 14;
    final starts = ends + segX2 + 2;
    final deltas = starts + segX2;
    final ranges = deltas + segX2;
    if (ranges + segX2 > t.length) return null;
    return (c) {
      for (var i = 0; i < segX2; i += 2) {
        if (c > t.u16(ends + i)) continue;
        final start = t.u16(starts + i);
        if (c < start) return 0;
        final delta = t.u16(deltas + i);
        final range = t.u16(ranges + i);
        if (range == 0) return (c + delta) & 0xFFFF;
        final p = ranges + i + range + 2 * (c - start);
        if (p + 2 > t.length) return 0;
        final g = t.u16(p);
        return g == 0 ? 0 : (g + delta) & 0xFFFF;
      }
      return 0;
    };
  }

  /// Ширины глифов похожи на моноширинный шрифт: почти все одной ширины,
  /// либо одной и двойной (полноширинные символы, значки).
  static bool widthsLookMonospace(List<int> advances) {
    final counts = <int, int>{};
    var total = 0;
    for (final a in advances) {
      if (a == 0) continue;
      counts[a] = (counts[a] ?? 0) + 1;
      total++;
    }
    if (total == 0) return false;
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    if (top.value >= total * 0.8) return true;
    if (sorted.length < 2) return false;
    final second = sorted[1];
    final pair = top.key == second.key * 2 || second.key == top.key * 2;
    return pair && top.value + second.value >= total * 0.9;
  }
}

class _Bytes {
  _Bytes(this.bytes);

  final Uint8List bytes;

  int get length => bytes.length;
  int u8(int o) => bytes[o];
  int u16(int o) => (bytes[o] << 8) | bytes[o + 1];
  int u32(int o) =>
      (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
}
