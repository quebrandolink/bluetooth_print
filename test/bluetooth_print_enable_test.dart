import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothPrint.enableBluetooth()', () {
    const channel = MethodChannel('bluetooth_print/methods');
    late BluetoothPrint bluetoothPrint;
    late List<MethodCall> capturedCalls;

    /// Instala um handler que responde apenas a `enableBluetooth`.
    void mockEnable(Future<Object?> Function() handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        capturedCalls.add(methodCall);
        if (methodCall.method == 'enableBluetooth') {
          return handler();
        }
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${methodCall.method} not implemented',
        );
      });
    }

    setUp(() {
      capturedCalls = <MethodCall>[];
      bluetoothPrint = BluetoothPrint();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('deve invocar o método enableBluetooth no canal nativo', () async {
      mockEnable(() async => true);

      await bluetoothPrint.enableBluetooth();

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.first.method, 'enableBluetooth');
      expect(capturedCalls.first.arguments, isNull);
    });

    test('deve retornar true quando o bluetooth já está ligado', () async {
      mockEnable(() async => true);

      expect(await bluetoothPrint.enableBluetooth(), isTrue);
    });

    test('deve retornar true quando o usuário aceita o diálogo', () async {
      mockEnable(() async => true);

      expect(await bluetoothPrint.enableBluetooth(), isTrue);
    });

    test('deve retornar false quando o usuário recusa, sem lançar', () async {
      mockEnable(() async => false);

      expect(await bluetoothPrint.enableBluetooth(), isFalse);
    });

    test('deve retornar false quando o nativo devolve null', () async {
      mockEnable(() async => null);

      expect(await bluetoothPrint.enableBluetooth(), isFalse);
    });

    group('erros', () {
      test('deve preservar o código bluetooth_unavailable do nativo', () async {
        mockEnable(() async => throw PlatformException(
              code: 'bluetooth_unavailable',
              message: 'O dispositivo não possui Bluetooth',
            ));

        await expectLater(
          bluetoothPrint.enableBluetooth(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'bluetooth_unavailable')
              .having((e) => e.message, 'message',
                  'O dispositivo não possui Bluetooth')),
        );
      });

      test('deve preservar o código no_activity do nativo', () async {
        mockEnable(() async => throw PlatformException(
              code: 'no_activity',
              message: 'enableBluetooth requer uma Activity em primeiro plano',
            ));

        await expectLater(
          bluetoothPrint.enableBluetooth(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'no_activity')),
        );
      });

      test('deve preservar o código no_permissions do nativo', () async {
        mockEnable(() async => throw PlatformException(
              code: 'no_permissions',
              message: 'enableBluetooth requer a permissão BLUETOOTH_CONNECT',
            ));

        await expectLater(
          bluetoothPrint.enableBluetooth(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'no_permissions')),
        );
      });

      test('deve usar mensagem padrão quando o nativo não envia message',
          () async {
        mockEnable(() async => throw PlatformException(code: 'no_activity'));

        await expectLater(
          bluetoothPrint.enableBluetooth(),
          throwsA(isA<BluetoothPrintException>().having(
              (e) => e.message, 'message', 'Erro ao ativar o bluetooth')),
        );
      });

      test(
          'deve usar enable_bluetooth_error para erro que não é PlatformException',
          () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        // Sem handler registrado o canal lança MissingPluginException
        await expectLater(
          bluetoothPrint.enableBluetooth(),
          throwsA(isA<BluetoothPrintException>()
              .having((e) => e.code, 'code', 'enable_bluetooth_error')),
        );
      });
    });
  });
}
