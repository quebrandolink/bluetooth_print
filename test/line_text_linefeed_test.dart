import 'package:bluetooth_print/src/models/line_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineText linefeed', () {
    test('feed() serializa 1 quebra', () {
      final line = LineText.feed();
      expect(line.linefeed, isTrue);
      expect(line.linefeedCount, 1);
      expect(line.toJson()['linefeed'], 1);
    });

    test('feed(2) serializa 2 quebras', () {
      final line = LineText.feed(2);
      expect(line.linefeed, isTrue);
      expect(line.linefeedCount, 2);
      expect(line.toJson()['linefeed'], 2);
    });

    test('linefeed: true serializa 1 quebra', () {
      final line = LineText(
        type: LineTextType.text,
        content: 'Olá',
        linefeed: true,
      );
      expect(line.linefeedCount, 1);
      expect(line.toJson()['linefeed'], 1);
    });

    test('fromJson preserva contagem múltipla', () {
      final line = LineText.fromJson({'linefeed': 3});
      expect(line.linefeed, isTrue);
      expect(line.linefeedCount, 3);
      expect(line.toJson()['linefeed'], 3);
    });

    test('sem linefeed serializa 0', () {
      final line = LineText(type: LineTextType.text, content: 'Olá');
      expect(line.linefeed, isFalse);
      expect(line.linefeedCount, 0);
      expect(line.toJson()['linefeed'], 0);
    });
  });
}
