import 'package:flutter_test/flutter_test.dart';
import 'package:vysh/app/terminal/terminal_input.dart';

void main() {
  group('Ctrl-комбинации', () {
    test('латиница - в верхний регистр', () {
      for (final c in ['c', 'C', 'a', 'z', 'd', 'u', 'l']) {
        expect(TerminalInput.ctrlLetter(c), c.toUpperCase());
      }
    });

    test('русская раскладка - по положению клавиши', () {
      expect(TerminalInput.ctrlLetter('с'), 'C');
      expect(TerminalInput.ctrlLetter('С'), 'C');
      expect(TerminalInput.ctrlLetter('в'), 'D');
      expect(TerminalInput.ctrlLetter('я'), 'Z');
      expect(TerminalInput.ctrlLetter('г'), 'U');
      expect(TerminalInput.ctrlLetter('д'), 'L');
      expect(TerminalInput.ctrlLetter('ф'), 'A');
    });

    test('цифры и пустая строка - не комбинации', () {
      expect(TerminalInput.ctrlLetter('1'), isNull);
      expect(TerminalInput.ctrlLetter(''), isNull);
    });

    test('управляющие байты', () {
      expect(TerminalInput.ctrlByte('c'), 3);
      expect(TerminalInput.ctrlByte('с'), 3); // русская «с»
      expect(TerminalInput.ctrlByte('['), 27);
      expect(TerminalInput.ctrlByte(' '), 0);
      expect(TerminalInput.ctrlByte('1'), isNull);
    });
  });

  group('набранная команда', () {
    test('ввод, Backspace, ^W, Enter', () {
      final t = TypedCommand()..feed('ls -la /tmp');
      expect(t.text, 'ls -la /tmp');
      t.feed('\x7f\x7f');
      expect(t.text, 'ls -la /t');
      t.feed('\x17');
      expect(t.text, 'ls -la ');
      t.feed('\r');
      expect(t.text, '');
    });

    test('^C и ^U очищают строку', () {
      final t = TypedCommand()..feed('echo hi');
      t.feed('\x03');
      expect(t.text, '');
      t.feed('abc\x15');
      expect(t.text, '');
    });
  });
}
