import 'dart:io';

/// Адреса хоста в порядке попыток подключения - общий для проверки
/// доступности и SSH, чтобы карточка и подключение вели себя одинаково.
///
/// IPv4 первым: при сломанном IPv6 (частый случай у домашних провайдеров)
/// иначе всё упиралось бы в таймаут на первом же AAAA-адресе.
/// Внутри семейства сохраняется порядок, который вернул резолвер.
Future<List<InternetAddress>> resolveHost(String host, {required Duration timeout}) async {
  final literal = InternetAddress.tryParse(host.replaceAll(RegExp(r'[\[\]]'), ''));
  if (literal != null) return [literal];
  final found = await InternetAddress.lookup(host).timeout(timeout);
  if (found.isEmpty) throw const SocketException('empty DNS answer');
  return [
    ...found.where((a) => a.type == InternetAddressType.IPv4),
    ...found.where((a) => a.type != InternetAddressType.IPv4),
  ];
}

/// Сколько адресов одного хоста пробовать, прежде чем сдаться.
const maxAddressAttempts = 3;
