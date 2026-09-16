import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothPrint — conexão', () {
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

    /// Faz `connect` falhar com o [code] que o nativo emitiria.
    void mockConnectError(String code, {String? message}) {
      mock('connect',
          () async => throw PlatformException(code: code, message: message));
    }

    final device = BluetoothDevice(
      name: 'Impressora',
      address: '02:23:34:93:F0:38',
      type: BluetoothDevice.TYPE_CLASSIC,
    );

    setUp(() {
      capturedCalls = <MethodCall>[];
      bluetoothPrint = BluetoothPrint();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('connect()', () {
      test('deve invocar connect com o payload do dispositivo', () async {
        mock('connect', () async => true);

        await bluetoothPrint.connect(device);

        expect(capturedCalls, hasLength(1));
        expect(capturedCalls.first.method, 'connect');
        expect(capturedCalls.first.arguments, {
          'name': 'Impressora',
          'address': '02:23:34:93:F0:38',
          'type': BluetoothDevice.TYPE_CLASSIC,
        });
      });

      test('deve retornar true quando o handshake conclui', () async {
        mock('connect', () async => true);

        expect(await bluetoothPrint.connect(device), isTrue);
      });

      test('deve retornar false quando o nativo devolve false', () async {
        mock('connect', () async => false);

        expect(await bluetoothPrint.connect(device), isFalse);
      });

      test('deve retornar false quando o nativo devolve null', () async {
        mock('connect', () async => null);

        expect(await bluetoothPrint.connect(device), isFalse);
      });
    });

    group('connect() — códigos de erro do nativo', () {
      test('deve preservar connection_timeout com a mensagem do nativo',
          () async {
        mockConnectError(
          'connection_timeout',
          message:
              'Impressora não respondeu ao handshake ESC/TSC/CPCL após 12000ms',
        );

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connection_timeout')
              .having(
                  (e) => e.message,
                  'message',
                  'Impressora não respondeu ao handshake ESC/TSC/CPCL após '
                      '12000ms')),
        );
      });

      test('deve preservar connection_lost quando o link cai no handshake',
          () async {
        mockConnectError(
          'connection_lost',
          message: 'A conexão com a impressora caiu antes do handshake '
              'ESC/TSC/CPCL',
        );

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connection_lost')),
        );
      });

      test('deve preservar printer_unreachable quando a porta nao abre',
          () async {
        mockConnectError(
          'printer_unreachable',
          message: 'Não foi possível abrir a porta. A impressora está desligada, '
              'fora de alcance ou conectada a outro aparelho.',
        );

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'printer_unreachable')),
        );
      });

      test('deve preservar connection_interrupted', () async {
        mockConnectError('connection_interrupted',
            message: 'Conexão interrompida');

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connection_interrupted')),
        );
      });

      test('deve preservar connection_error', () async {
        mockConnectError('connection_error', message: 'Erro durante a conexão');

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connection_error')),
        );
      });

      test('deve preservar connection_failed', () async {
        mockConnectError('connection_failed',
            message: 'Erro inicial na conexão');

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connection_failed')),
        );
      });

      test('deve preservar invalid_argument', () async {
        mockConnectError('invalid_argument',
            message: 'Endereço MAC inválido ou ausente');

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'invalid_argument')),
        );
      });

      test('deve usar mensagem padrão quando o nativo não envia message',
          () async {
        mockConnectError('connection_timeout');

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.message, 'message', 'Erro ao conectar')),
        );
      });

      test('deve usar connect_error para erro que não é PlatformException',
          () async {
        // Sem handler registrado o canal lança MissingPluginException.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        await expectLater(
          bluetoothPrint.connect(device),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'connect_error')),
        );
      });
    });

    group('disconnect()', () {
      test('deve invocar disconnect e retornar true', () async {
        mock('disconnect', () async => true);

        expect(await bluetoothPrint.disconnect(), isTrue);
        expect(capturedCalls.single.method, 'disconnect');
      });

      test('deve lançar disconnect_error quando o canal falha', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        await expectLater(
          bluetoothPrint.disconnect(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'disconnect_error')),
        );
      });
    });

    group('isConnected', () {
      test('deve retornar true quando a impressora está pronta', () async {
        mock('isConnected', () async => true);

        expect(await bluetoothPrint.isConnected, isTrue);
        expect(capturedCalls.single.method, 'isConnected');
      });

      test('deve retornar false quando não há impressora conectada', () async {
        mock('isConnected', () async => false);

        expect(await bluetoothPrint.isConnected, isFalse);
      });

      test('deve retornar false quando o nativo devolve null', () async {
        mock('isConnected', () async => null);

        expect(await bluetoothPrint.isConnected, isFalse);
      });
    });
  });
}
