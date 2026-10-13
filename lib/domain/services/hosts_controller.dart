import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infra/platform/net_resolve.dart';
import '../../infra/storage/json_store.dart';
import '../models/host.dart';
import '../ports/secret_store.dart';
import 'ports_providers.dart';

final hostsProvider = NotifierProvider<HostsController, List<Host>>(HostsController.new);

class HostsController extends Notifier<List<Host>> {
  final _store = JsonStore('hosts.json');

  @override
  List<Host> build() {
    final raw = _store.readSync();
    if (raw is! List) return const [];
    // Одна испорченная запись не должна стоить всего списка.
    final hosts = <Host>[];
    for (final item in raw) {
      if (item is! Map<String, Object?>) continue;
      try {
        final h = Host.fromJson(item);
        if (h.address.isNotEmpty) hosts.add(h);
      } catch (e) {
        debugPrint('vysh: пропущена запись hosts.json: $e');
      }
    }
    return hosts;
  }

  void upsert(Host host) {
    final i = state.indexWhere((h) => h.id == host.id);
    state = i < 0
        ? [...state, host]
        : [for (final h in state) h.id == host.id ? host : h];
    _persist();
  }

  void remove(String id) {
    removeMany([id]);
  }

  /// Удалить несколько хостов разом (вместе с их сохранёнными паролями).
  void removeMany(Iterable<String> ids) {
    final set = ids.toSet();
    if (set.isEmpty) return;
    state = state.where((h) => !set.contains(h.id)).toList();
    _persist();
    for (final id in set) {
      // Хост уже удалён из списка; секрет, который не удалось стереть,
      // только логируем - показать его пользователю всё равно негде.
      forgetSecrets(id).catchError((Object e) {
        debugPrint('vysh: не удалось удалить пароль хоста $id: $e');
      });
    }
  }

  /// Забыть сохранённые пароль и парольную фразу хоста.
  /// Бросает исключение, если системное хранилище недоступно.
  Future<void> forgetSecrets(String id) async {
    final secrets = ref.read(secretStoreProvider);
    await secrets.delete(passwordKey(id));
    await secrets.delete(passphraseKey(id));
  }

  void touch(String id) {
    if (!state.any((h) => h.id == id)) return;
    final now = DateTime.now();
    state = [for (final h in state) h.id == id ? h.withLastConnected(now) : h];
    _persist();
  }

  void _persist() => _store.write(state.map((h) => h.toJson()).toList());
}

/// Список существующих групп (для подсказок в редакторе).
final hostGroupsProvider = Provider<List<String>>((ref) {
  final groups = ref.watch(hostsProvider).map((h) => h.group.trim()).where((g) => g.isNotEmpty).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return groups;
});

/// Доступность хоста: время TCP-подключения к порту SSH в мс
/// или причина, по которой подключиться не удалось.
typedef Reachability = ({int? ms, String? error});

final reachabilityProvider = FutureProvider.autoDispose
    .family<Reachability, (String, int)>((ref, target) async {
  final host = target.$1.trim();
  final port = target.$2;

  // Тот же порядок адресов, что и при SSH-подключении (IPv4 первым).
  List<InternetAddress> addrs;
  try {
    addrs = await resolveHost(host, timeout: const Duration(seconds: 4));
  } catch (e) {
    return (ms: null, error: 'DNS: ${_reason(e)}');
  }

  await _probeSlots.acquire();
  try {
    String? error;
    // Вторая попытка - на случай потерянного пакета или лимита новых
    // подключений на сервере (ufw limit, fail2ban).
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 700));
      for (final addr in addrs.take(maxAddressAttempts)) {
        final sw = Stopwatch()..start();
        try {
          final socket =
              await Socket.connect(addr, port, timeout: const Duration(seconds: 4));
          socket.destroy();
          return (ms: sw.elapsedMilliseconds, error: null);
        } catch (e) {
          error = '${addr.address}: ${_reason(e)}';
        }
      }
    }
    return (ms: null, error: error);
  } finally {
    _probeSlots.release();
  }
});

/// Не больше 16 проверок доступности одновременно: при сотне хостов
/// иначе разом открывалась сотня сокетов.
final _probeSlots = _Semaphore(16);

class _Semaphore {
  _Semaphore(this._free);
  int _free;
  final _waiting = <Completer<void>>[];

  Future<void> acquire() {
    if (_free > 0) {
      _free--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _free++;
    }
  }
}

String _reason(Object e) => switch (e) {
      SocketException(:final osError?) => osError.message.trim(),
      SocketException(:final message) => message,
      TimeoutException() => 'timeout',
      _ => e.toString(),
    };
