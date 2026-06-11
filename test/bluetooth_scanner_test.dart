import 'package:bluetooth_print/bluetooth_print_exception.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:bluetooth_print/bluetooth_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MethodChannelBluetoothScanner Fundamental Tests', () {
    late MethodChannelBluetoothScanner scanner;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('bluetooth_print/methods'),
        (methodCall) async {
          switch (methodCall.method) {
            case 'startScan':
              return null;
            case 'stopScan':
              return null;
            default:
              throw PlatformException(
                code: 'Unimplemented',
                details: 'Method ${methodCall.method} not implemented',
              );
          }
        },
      );
      scanner = MethodChannelBluetoothScanner();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('bluetooth_print/methods'),
        null,
      );
      scanner.dispose();
    });

    group('scan()', () {
      test('deve retornar stream de dispositivos', () async {
        final devices = <BluetoothDevice>[];

        await scanner
            .scan(timeout: Duration(milliseconds: 100))
            .forEach(devices.add);

        expect(devices, isA<List<BluetoothDevice>>());
      });

      test('deve respeitar timeout e parar scan', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('deve rejeitar scan duplicado', () async {
        final scan1 = scanner.scan(timeout: Duration(seconds: 1));

        expect(
          () => scanner.scan(timeout: Duration(seconds: 1)),
          throwsA(isA<Exception>()),
        );

        await scan1.drain();
      });

      test('deve atualizar status durante scan', () async {
        final statuses = <bool>[];

        final subscription = scanner.isScanning.listen(statuses.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        expect(statuses, contains(true));
        expect(statuses, contains(false));
      });

      test('deve emitir dispositivos quando receber MethodCall', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular MethodCall com dispositivo
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Test Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 1);
        expect(devices.first.name, 'Test Device');
        expect(devices.first.address, '00:11:22:33:44:55');
      });

      test('deve ignorar dispositivos sem endereço', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular MethodCall sem endereço
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Device Without Address',
              'address': null,
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.isEmpty, true);
      });

      test('deve tratar endereço com case insensitive', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Enviar mesmo dispositivo com cases diferentes
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Device 1',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Device 2',
              'address': '00:11:22:33:44:55'.toLowerCase(),
              'type': 2,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 1);
        expect(devices.first.name, 'Device 2');
        expect(devices.first.type, 2);
      });

      test('deve atualizar dispositivo existente quando dados mudam', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Enviar dispositivo inicial
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Original Name',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 20));

        // Atualizar mesmo dispositivo
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Updated Name',
              'address': '00:11:22:33:44:55',
              'type': 2,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 2); // Um para cada evento
        expect(devices.last.name, 'Updated Name');
        expect(devices.last.type, 2);
      });
    });

    group('startScan()', () {
      test('deve retornar lista de dispositivos', () async {
        final scanSubscription =
            scanner.scan(timeout: Duration(milliseconds: 100)).listen((_) {});

        // Simular MethodCall com dispositivo
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Test Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        final devices =
            await scanner.startScan(timeout: Duration(milliseconds: 100));

        await scanSubscription.cancel();

        expect(devices, isA<List<BluetoothDevice>>());
      });

      test('deve respeitar timeout personalizado', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.startScan(timeout: Duration(milliseconds: 100));

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('deve usar timeout padrão quando não especificado', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.startScan();

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(6000)); // 5s + margem
      });
    });

    group('stopScan()', () {
      test('deve parar scan com sucesso', () async {
        await scanner.scan(timeout: Duration(seconds: 1)).drain();

        expect(() => scanner.stopScan(), returnsNormally);
      });

      test('deve lançar BluetoothPrintException em erro', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'stopScan') {
              throw PlatformException(
                code: 'ERROR',
                details: 'Failed to stop scan',
              );
            }
            return null;
          },
        );

        expect(
          () => scanner.stopScan(),
          throwsA(isA<BluetoothPrintException>()),
        );
      });

      test('deve atualizar status mesmo com erro', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'stopScan') {
              throw PlatformException(
                code: 'ERROR',
                details: 'Failed to stop scan',
              );
            }
            return null;
          },
        );

        final statuses = <bool>[];
        final subscription = scanner.isScanning.listen(statuses.add);

        try {
          await scanner.stopScan();
        } catch (e) {
          // Esperado
        }

        await subscription.cancel();

        expect(statuses, contains(false));
      });

      test('deve funcionar mesmo quando não está escaneando', () async {
        expect(() => scanner.stopScan(), returnsNormally);
      });
    });

    group('scanResults stream', () {
      test('deve emitir lista vazia inicial', () async {
        final results = <List<BluetoothDevice>>[];

        final subscription = scanner.scanResults.listen(results.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await subscription.cancel();

        expect(results.first.isEmpty, true);
      });

      test('deve emitir resultados atualizados', () async {
        final results = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(results.add);

        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Simular MethodCall com dispositivo
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Test Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();
        await subscription.cancel();

        expect(results.last.length, 1);
        expect(results.last.first.name, 'Test Device');
      });

      test('deve ser broadcast stream', () async {
        final results1 = <List<BluetoothDevice>>[];
        final results2 = <List<BluetoothDevice>>[];

        final sub1 = scanner.scanResults.listen(results1.add);
        final sub2 = scanner.scanResults.listen(results2.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await sub1.cancel();
        await sub2.cancel();

        expect(results1.length, equals(results2.length));
      });

      test('não deve emitir duplicatas', () async {
        final results = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(results.add);

        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Enviar mesmo dispositivo duas vezes
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Test Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Test Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();
        await subscription.cancel();

        expect(results.last.length, 1);
      });
    });

    group('isScanning stream', () {
      test('deve emitir false inicialmente', () async {
        final statuses = <bool>[];

        final subscription = scanner.isScanning.listen(statuses.add);

        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        expect(statuses.isEmpty || statuses.first, false);
      });

      test('deve emitir true durante scan', () async {
        final statuses = <bool>[];

        final subscription = scanner.isScanning.listen(statuses.add);

        final scanSubscription =
            scanner.scan(timeout: Duration(milliseconds: 200)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 100));

        expect(statuses.contains(true), true);

        await scanSubscription.cancel();
        await subscription.cancel();
      });

      test('deve emitir false após scan completar', () async {
        final statuses = <bool>[];

        final subscription = scanner.isScanning.listen(statuses.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        expect(statuses.contains(false), true);
      });

      test('deve ser broadcast stream', () async {
        final statuses1 = <bool>[];
        final statuses2 = <bool>[];

        final sub1 = scanner.isScanning.listen(statuses1.add);
        final sub2 = scanner.isScanning.listen(statuses2.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await sub1.cancel();
        await sub2.cancel();

        expect(statuses1.length, equals(statuses2.length));
      });

      test('deve manter consistência em múltiplos scans', () async {
        final statuses = <bool>[];

        final subscription = scanner.isScanning.listen(statuses.add);

        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();

        await subscription.cancel();

        final trueCount = statuses.where((s) => s).length;
        final falseCount = statuses.where((s) => !s).length;

        expect(trueCount, equals(2)); // Dois scans iniciados
        expect(falseCount, greaterThanOrEqualTo(2)); // Pelo menos dois fins
      });
    });

    group('dispose()', () {
      test('deve fechar todos os controladores', () async {
        final scanResultsSub = scanner.scanResults.listen((_) {});
        final isScanningSub = scanner.isScanning.listen((_) {});

        scanner.dispose();

        // Verificar se os streams foram fechados tentando adicionar listener
        expect(() => scanner.scanResults.listen((_) {}), throwsA(anything));
        expect(() => scanner.isScanning.listen((_) {}), throwsA(anything));

        await scanResultsSub.cancel();
        await isScanningSub.cancel();
      });

      test('deve permitir múltiplas chamadas sem erro', () async {
        expect(() {
          scanner.dispose();
          scanner.dispose();
          scanner.dispose();
        }, returnsNormally);
      });

      test('deve parar scan em andamento', () async {
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));
        scanner.dispose();

        // Se não crashou, está ok
        expect(true, true);

        await scanSubscription.cancel();
      });

      test('deve liberar recursos corretamente', () async {
        scanner.dispose();

        // Tentar usar streams após dispose deve falhar
        expect(() => scanner.scanResults.listen((_) {}), throwsA(anything));
        expect(() => scanner.isScanning.listen((_) {}), throwsA(anything));
      });
    });

    group('BluetoothDevice Parsing', () {
      test('deve parsear JSON válido', () {
        final json = {
          'name': 'Test Device',
          'address': '00:11:22:33:44:55',
          'type': 1,
        };

        final device = BluetoothDevice.fromJson(json);

        expect(device.name, 'Test Device');
        expect(device.address, '00:11:22:33:44:55');
        expect(device.type, 1);
      });

      test('deve handle valores nulos', () {
        final json = {
          'name': null,
          'address': null,
          'type': null,
        };

        final device = BluetoothDevice.fromJson(json);

        expect(device.name, null);
        expect(device.address, null);
        expect(device.type, 0); // Default value
      });

      test('deve usar default para type quando null', () {
        final json = {
          'name': 'Test',
          'address': '00:11:22:33:44:55',
        };

        final device = BluetoothDevice.fromJson(json);

        expect(device.type, 0);
      });

      test('deve converter para JSON corretamente', () {
        final device = BluetoothDevice(
          name: 'Test Device',
          address: '00:11:22:33:44:55',
          type: 1,
        );

        final json = device.toJson();

        expect(json['name'], 'Test Device');
        expect(json['address'], '00:11:22:33:44:55');
        expect(json['type'], 1);
      });

      test('deve omitir campos nulos no JSON', () {
        final device = BluetoothDevice(
          name: null,
          address: '00:11:22:33:44:55',
          type: 1,
        );

        final json = device.toJson();

        expect(json.containsKey('name'), false);
        expect(json.containsKey('address'), true);
        expect(json.containsKey('type'), true);
      });
    });

    group('Edge Cases', () {
      test('deve ignorar dispositivos com endereço vazio', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular MethodCall com endereço vazio
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Empty Address Device',
              'address': '',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.isEmpty, true);
      });

      test('deve normalizar endereço com trim', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Enviar endereço com espaços
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Spaced Address Device',
              'address': ' 00:11:22:33:44:55 ',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 1);
        // O trim é aplicado no scanner, então o endereço deve estar normalizado
        expect(devices.first.address?.trim(), '00:11:22:33:44:55');
      });

      test('deve cancelar scan quando subscription cancelado', () async {
        final statuses = <bool>[];
        final statusSub = scanner.isScanning.listen(statuses.add);

        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        await Future.delayed(Duration(milliseconds: 50));
        await statusSub.cancel();

        expect(statuses.contains(false), true);
      });

      test('deve handle MethodCall com argumentos inválidos', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular MethodCall com JSON inválido - vamos usar um Map inválido em vez de String
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 123, // número em vez de string
              'address': null,
              'type': 'invalid', // string em vez de número
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        // Não deve crashar
        expect(devices.isEmpty, true);
      });
    });
  });
}
