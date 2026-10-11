/// Нагрузка Linux-сервера: одна команда по /proc раз в несколько секунд.
library;

/// Команда для сервера. Разделы разделены строкой `@@`. Только POSIX-утилиты
/// и /proc, без bash-синтаксиса: работает и в sh, и в fish, и в busybox.
const serverStatsCommand = 'head -n1 /proc/stat; echo @@; '
    'grep -E "^(MemTotal|MemAvailable):" /proc/meminfo; echo @@; '
    'cat /proc/uptime; echo @@; '
    'df -Pk / | tail -n1; echo @@; '
    'cat /proc/net/dev';

class ServerStats {
  const ServerStats({
    this.cpu,
    required this.memUsed,
    required this.memTotal,
    this.diskUsed,
    this.diskTotal,
    required this.uptime,
    this.rxPerSec,
    this.txPerSec,
  });

  /// Загрузка CPU, 0..1. null - нужен второй замер.
  final double? cpu;

  /// Байты.
  final int memUsed;
  final int memTotal;
  final int? diskUsed;
  final int? diskTotal;
  final Duration uptime;

  /// Байт в секунду. null - нужен второй замер.
  final double? rxPerSec;
  final double? txPerSec;

  double get mem => memTotal == 0 ? 0 : memUsed / memTotal;
  double? get disk =>
      diskUsed == null || diskTotal == null || diskTotal == 0 ? null : diskUsed! / diskTotal!;
}

/// Разбирает вывод [serverStatsCommand]. CPU и сеть считаются по разнице
/// с прошлым замером, поэтому объект живёт, пока открыта вкладка.
class ServerStatsSampler {
  int? _cpuTotal, _cpuIdle;
  int? _rx, _tx;
  DateTime? _at;

  /// null - вывод не похож на Linux (/proc нет), статистику не показываем.
  ServerStats? parse(String raw, DateTime now) {
    final parts = raw.split(RegExp(r'^@@\s*$', multiLine: true));
    if (parts.length < 5) return null;

    // CPU: "cpu  user nice system idle iowait irq softirq steal ..."
    // Строки до неё (приветствие из .bashrc и т.п.) пропускаем.
    final cpuLine = parts[0]
        .split('\n')
        .map((l) => l.trim())
        .lastWhere((l) => l.startsWith('cpu '), orElse: () => '');
    final cpuF = cpuLine.split(RegExp(r'\s+'));
    if (cpuF.length < 5 || cpuF.first != 'cpu') return null;
    final nums = cpuF.skip(1).take(8).map(int.tryParse).whereType<int>().toList();
    if (nums.length < 4) return null;
    final total = nums.fold<int>(0, (a, b) => a + b);
    final idle = nums[3] + (nums.length > 4 ? nums[4] : 0);
    double? cpu;
    if (_cpuTotal != null && total > _cpuTotal!) {
      final dt = total - _cpuTotal!;
      final di = idle - _cpuIdle!;
      cpu = ((dt - di) / dt).clamp(0.0, 1.0);
    }
    _cpuTotal = total;
    _cpuIdle = idle;

    // Память, kB.
    int? memTotal, memAvail;
    for (final line in parts[1].split('\n')) {
      final m = RegExp(r'^(\w+):\s+(\d+)').firstMatch(line.trim());
      if (m == null) continue;
      final v = int.parse(m.group(2)!) * 1024;
      if (m.group(1) == 'MemTotal') memTotal = v;
      if (m.group(1) == 'MemAvailable') memAvail = v;
    }
    if (memTotal == null) return null;

    // Аптайм, секунды.
    final up = double.tryParse(parts[2].trim().split(RegExp(r'\s+')).first) ?? 0;

    // Диск /: "fs 1024-blocks used available capacity mount"
    int? diskUsed, diskTotal;
    final df = parts[3].trim().split(RegExp(r'\s+'));
    if (df.length >= 4) {
      final size = int.tryParse(df[1]);
      final used = int.tryParse(df[2]);
      final avail = int.tryParse(df[3]);
      if (size != null && used != null && avail != null) {
        // Как в df: занято / (занято + доступно), без зарезервированного root.
        diskUsed = used * 1024;
        diskTotal = (used + avail) * 1024;
      }
    }

    // Сеть: сумма по физическим интерфейсам, без lo и мостов контейнеров.
    var rx = 0, tx = 0;
    for (final line in parts[4].split('\n')) {
      final i = line.indexOf(':');
      if (i < 0) continue;
      final name = line.substring(0, i).trim();
      if (_virtual.hasMatch(name)) continue;
      final f = line.substring(i + 1).trim().split(RegExp(r'\s+'));
      if (f.length < 9) continue;
      rx += int.tryParse(f[0]) ?? 0;
      tx += int.tryParse(f[8]) ?? 0;
    }
    double? rxRate, txRate;
    final prevAt = _at;
    if (prevAt != null && _rx != null) {
      final sec = now.difference(prevAt).inMilliseconds / 1000;
      // Счётчик сбросился (перезапуск интерфейса) - пропускаем замер.
      if (sec > 0 && rx >= _rx! && tx >= _tx!) {
        rxRate = (rx - _rx!) / sec;
        txRate = (tx - _tx!) / sec;
      }
    }
    _rx = rx;
    _tx = tx;
    _at = now;

    return ServerStats(
      cpu: cpu,
      memUsed: memTotal - (memAvail ?? 0),
      memTotal: memTotal,
      diskUsed: diskUsed,
      diskTotal: diskTotal,
      uptime: Duration(seconds: up.round()),
      rxPerSec: rxRate,
      txPerSec: txRate,
    );
  }

  static final _virtual =
      RegExp(r'^(lo|veth|docker|br-|virbr|cni|flannel|cali|lxc|kube|vnet|tap)');
}

/// 1536 → «1.5 КБ».
String formatBytes(num bytes, {required bool ru}) {
  const ruU = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  const enU = ['B', 'KB', 'MB', 'GB', 'TB'];
  final units = ru ? ruU : enU;
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final text = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$text ${units[i]}';
}

/// 5 д 3 ч / 3 ч 12 мин / 12 мин.
String formatUptime(Duration d, {required bool ru}) {
  final days = d.inDays, hours = d.inHours % 24, mins = d.inMinutes % 60;
  if (days > 0) return ru ? '$days д $hours ч' : '${days}d ${hours}h';
  if (hours > 0) return ru ? '$hours ч $mins мин' : '${hours}h ${mins}m';
  return ru ? '$mins мин' : '${mins}m';
}
