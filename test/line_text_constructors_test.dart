import 'package:bluetooth_print/src/models/line_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineText named constructors', () {
    test('text aplica estilos e linesAfter', () {
      final line = LineText.text(
        'Olá',
        styles: LineTextStyles.bold,
        linesAfter: 1,
      );

      expect(line.type, LineTextType.text);
      expect(line.content, 'Olá');
      expect(line.weight, TextWeight.bold);
      expect(line.linefeedCount, 1);
      expect(line.toJson()['linefeed'], 1);
      expect(line.toJson()['weight'], 1);
    });

    test('text com centerBold preset', () {
      final line = LineText.text('Título', styles: LineTextStyles.centerBold);

      expect(line.align, TextAlign.center);
      expect(line.weight, TextWeight.bold);
    });

    test('barcode define type e content', () {
      final line = LineText.barcode('1234567890', size: 8, linesAfter: 1);

      expect(line.type, LineTextType.barcode);
      expect(line.content, '1234567890');
      expect(line.size, 8);
      expect(line.align, TextAlign.center);
      expect(line.toJson()['type'], 'barcode');
    });

    test('qrcode define type e content', () {
      final line = LineText.qrcode('https://exemplo.com', size: 5);

      expect(line.type, LineTextType.qrcode);
      expect(line.content, 'https://exemplo.com');
      expect(line.size, 5);
    });

    test('image define type e content base64', () {
      final line = LineText.image('base64payload', linesAfter: 1);

      expect(line.type, LineTextType.image);
      expect(line.content, 'base64payload');
      expect(line.linefeedCount, 1);
    });

    test('labelText define coordenadas TSC', () {
      final line = LineText.labelText('Produto', x: 10, y: 60);

      expect(line.type, LineTextType.text);
      expect(line.content, 'Produto');
      expect(line.x, 10);
      expect(line.y, 60);
    });

    test('text com reverse serializa corretamente', () {
      final line = LineText.text(
        'Rev',
        styles: const LineTextStyles(reverse: true),
      );

      expect(line.reverse, isTrue);
      expect(line.toJson()['reverse'], 1);
    });

    test('fromJson preserva reverse', () {
      final line = LineText.fromJson({'type': 'text', 'content': 'Rev', 'reverse': 1});

      expect(line.reverse, isTrue);
      expect(line.toJson()['reverse'], 1);
    });

    test('toJson round-trip preserva estilos de texto', () {
      final original = LineText.text(
        'Teste',
        styles: const LineTextStyles(
          align: TextAlign.center,
          weight: TextWeight.bold,
          width: TextWidth.doubled,
          height: TextHeight.doubled,
          fontSize: FontSize.x2,
          underline: true,
        ),
        linesAfter: 2,
      );

      final restored = LineText.fromJson(original.toJson());

      expect(restored.type, LineTextType.text);
      expect(restored.content, 'Teste');
      expect(restored.align, TextAlign.center);
      expect(restored.weight, TextWeight.bold);
      expect(restored.width, TextWidth.doubled);
      expect(restored.height, TextHeight.doubled);
      expect(restored.fontSize, FontSize.x2);
      expect(restored.underline, isTrue);
      expect(restored.linefeedCount, 2);
    });
  });
}
