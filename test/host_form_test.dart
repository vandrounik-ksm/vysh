import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/domain/models/host.dart';
import 'package:vysh/ui/hosts/host_form.dart';

void main() {
  test('вставка user@host:port раскладывается по полям', () {
    final f = HostForm(null, initialLabel: '');
    f.address.text = 'admin@10.0.0.5:2222';
    f.onAddressChanged(f.address.text);
    expect(f.address.text, '10.0.0.5');
    expect(f.port.text, '2222');
    expect(f.user.text, 'admin');
    f.dispose();
  });

  test('host:port без пользователя не трогает поле пользователя', () {
    final f = HostForm(null, initialLabel: '')..user.text = 'me';
    f.onAddressChanged('example.com:2200');
    expect(f.user.text, 'me');
    expect(f.port.text, '2200');
    f.dispose();
  });

  test('сборка хоста: пустой пользователь - root, ключ только для входа по ключу', () {
    final f = HostForm(null, initialLabel: ' web ')
      ..address.text = ' example.com '
      ..keyPath.text = '~/.ssh/id';
    var h = f.toHost(id: 'x');
    expect((h.label, h.address, h.username, h.keyPath), ('web', 'example.com', 'root', null));
    f.auth = AuthMethod.key;
    h = f.toHost(id: 'x');
    expect(h.keyPath, '~/.ssh/id');
    f.dispose();
  });

  test('правка существующего хоста начинается с его значений', () {
    const src = Host(id: 'h', label: 'l', address: 'a', port: 2200, username: 'u', keepAliveSeconds: 0);
    final f = HostForm(src, initialLabel: src.label);
    final h = f.toHost(id: src.id);
    expect((h.port, h.username, h.keepAliveSeconds), (2200, 'u', 0));
    f.dispose();
  });

  test('проверка порта', () {
    expect(HostForm.validPort('22'), isTrue);
    expect(HostForm.validPort('0'), isFalse);
    expect(HostForm.validPort('70000'), isFalse);
    expect(HostForm.validPort(''), isFalse);
  });
}
