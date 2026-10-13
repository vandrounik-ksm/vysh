import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/l10n/app_strings.dart';
import 'package:vysh/domain/services/server_stats.dart';

String sample({required int busy, required int idle, required int rx, required int tx}) => '''
welcome from bashrc
cpu  $busy 0 0 $idle 0 0 0 0 0 0
@@
MemTotal:        8000000 kB
MemAvailable:    6000000 kB
@@
447.12 874.95
@@
/dev/vda         264212084 14693736  30737408      33% /
@@
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:  999999      23    0    0    0     0          0         0   999999      23    0    0    0     0       0          0
  eth0: $rx    6510    0    5    0     0          0         0 $tx    6575    0    0    0     0       0          0
''';

void main() {
  test('первый замер без CPU и сети, второй с ними', () {
    final s = ServerStatsSampler();
    final t0 = DateTime(2026);
    final a = s.parse(sample(busy: 100, idle: 900, rx: 1000, tx: 2000), t0)!;
    expect(a.cpu, isNull);
    expect(a.rxPerSec, isNull);
    expect(a.memTotal, 8000000 * 1024);
    expect(a.memUsed, 2000000 * 1024);
    expect(a.uptime, const Duration(seconds: 447));
    expect(a.disk, closeTo(14693736 / (14693736 + 30737408), 1e-9));

    final b = s.parse(
      sample(busy: 150, idle: 950, rx: 4000, tx: 2600),
      t0.add(const Duration(seconds: 2)),
    )!;
    expect(b.cpu, closeTo(0.5, 1e-9));
    expect(b.rxPerSec, 1500);
    expect(b.txPerSec, 300);
  });

  test('не Linux', () {
    expect(ServerStatsSampler().parse('sh: /proc/stat: not found', DateTime(2026)), isNull);
  });

  test('форматирование', () {
    expect(const AppStrings(isRu: true).bytes(1536), '1.5 КБ');
    expect(const AppStrings(isRu: true).uptime(const Duration(days: 5, hours: 3)), '5 д 3 ч');
  });
}
