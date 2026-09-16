import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothPrint — impressão', () {
    const channel = MethodChannel('bluetooth_print/methods');
    late BluetoothPrint bluetoothPrint;
    late List<MethodCall> capturedCalls;

    /// Instala um handler que responde apenas a [method].
    void mock(String method, Future<Object?> Function() handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        capturedCalls.add(methodCall);
        if (methodCall.method == method) {
          return handler();
        }
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${methodCall.method} not implemented',
        );
      });
    }

    /// Faz [method] falhar com o [code] que o nativo emitiria.
    void mockError(String method, String code, {String? message}) {
      mock(method,
          () async => throw PlatformException(code: code, message: message));
    }

    /// Remove o handler: o canal passa a lançar MissingPluginException.
    void semHandler() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }

    final data = [LineText.text('Olá', linesAfter: 1)];

    setUp(() {
      capturedCalls = <MethodCall>[];
      bluetoothPrint = BluetoothPrint();
    });

    tearDown(semHandler);

    group('printReceipt()', () {
      test('deve enviar config e data serializados', () async {
        mock('printReceipt', () async => true);

        await bluetoothPrint.printReceipt(config: {'foo': 1}, data: data);

        expect(capturedCalls, hasLength(1));
        expect(capturedCalls.first.method, 'printReceipt');
        final args = capturedCalls.first.arguments as Map;
        expect(args['config'], {'foo': 1});
        expect(args['data'], [data.first.toJson()]);
      });

      test('deve retornar true em caso de sucesso', () async {
        mock('printReceipt', () async => true);

        expect(
          await bluetoothPrint.printReceipt(config: {}, data: data),
          isTrue,
        );
      });

      // Regressão: este erro chegava ao app do usuário como exceção não
      // tratada. O contrato é que ele chegue tipado, com o código preservado,
      // para o chamador poder ressincronizar a UI.
      test('deve propagar "not connect" como BluetoothPrintException',
          () async {
        mockError('printReceipt', 'not connect',
            message: 'estado da conexão inválido');

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'not connect')
              .having((e) => e.message, 'message', 'estado da conexão inválido')),
        );
      });

      test('deve preservar printer_not_ready', () async {
        mockError('printReceipt', 'printer_not_ready',
            message:
                'A impressora ainda não respondeu o tipo de comando (ESC/TSC/CPCL)');

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'printer_not_ready')),
        );
      });

      test('deve preservar print_failed', () async {
        mockError('printReceipt', 'print_failed',
            message: 'Falha ao escrever os dados na impressora');

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'print_failed')),
        );
      });

      test('deve preservar invalid_arguments', () async {
        mockError('printReceipt', 'invalid_arguments',
            message: 'por favor adicione config ou data');

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'invalid_arguments')),
        );
      });

      test('deve usar mensagem padrão quando o nativo não envia message',
          () async {
        mockError('printReceipt', 'not connect');

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.message, 'message', 'Erro ao imprimir recibo')),
        );
      });

      test('deve usar print_receipt_error para erro que não é PlatformException',
          () async {
        semHandler();

        await expectLater(
          bluetoothPrint.printReceipt(config: {}, data: data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'print_receipt_error')),
        );
      });
    });

    group('printLabel()', () {
      test('deve enviar as dimensões da etiqueta em config', () async {
        mock('printLabel', () async => true);

        await bluetoothPrint
            .printLabel({'width': 40, 'height': 70, 'gap': 2}, data);

        expect(capturedCalls.single.method, 'printLabel');
        final args = capturedCalls.single.arguments as Map;
        expect(args['config'], {'width': 40, 'height': 70, 'gap': 2});
        expect(args['data'], [data.first.toJson()]);
      });

      test('deve retornar true em caso de sucesso', () async {
        mock('printLabel', () async => true);

        expect(await bluetoothPrint.printLabel({}, data), isTrue);
      });

      test('deve propagar "not connect" como BluetoothPrintException',
          () async {
        mockError('printLabel', 'not connect',
            message: 'estado da conexão inválido');

        await expectLater(
          bluetoothPrint.printLabel({}, data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'not connect')),
        );
      });

      test('deve preservar printer_not_ready', () async {
        mockError('printLabel', 'printer_not_ready');

        await expectLater(
          bluetoothPrint.printLabel({}, data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'printer_not_ready')
              .having((e) => e.message, 'message', 'Erro ao imprimir etiqueta')),
        );
      });

      test('deve usar print_label_error para erro que não é PlatformException',
          () async {
        semHandler();

        await expectLater(
          bluetoothPrint.printLabel({}, data),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'print_label_error')),
        );
      });
    });

    group('printTest()', () {
      test('deve invocar printTest sem argumentos', () async {
        mock('printTest', () async => true);

        await bluetoothPrint.printTest();

        expect(capturedCalls.single.method, 'printTest');
        expect(capturedCalls.single.arguments, isNull);
      });

      test('deve propagar "not connect" como BluetoothPrintException',
          () async {
        mockError('printTest', 'not connect',
            message: 'estado da conexão inválido');

        await expectLater(
          bluetoothPrint.printTest(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'not connect')),
        );
      });

      test('deve preservar printer_not_ready', () async {
        mockError('printTest', 'printer_not_ready');

        await expectLater(
          bluetoothPrint.printTest(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'printer_not_ready')
              .having(
                  (e) => e.message, 'message', 'Erro no teste de impressão')),
        );
      });

      test('deve usar print_test_error para erro que não é PlatformException',
          () async {
        semHandler();

        await expectLater(
          bluetoothPrint.printTest(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'print_test_error')),
        );
      });
    });
  });
}
