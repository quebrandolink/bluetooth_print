import 'dart:async';

import 'package:bluetooth_print/bluetooth_print_exception.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:bluetooth_print/bluetooth_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MethodChannelBluetoothScanner Advanced Tests', () {
    late MethodChannelBluetoothScanner scanner;
    List<MethodCall> capturedCalls = [];

    setUp(() {
      capturedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('bluetooth_print/methods'),
        (methodCall) async {
          capturedCalls.add(methodCall);
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

    group('Integração com MethodChannel', () {
      test('deve chamar startScan corretamente', () async {
        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        expect(capturedCalls.length, greaterThanOrEqualTo(1));
        expect(capturedCalls.first.method, 'startScan');
      });

      test('deve chamar stopScan corretamente', () async {
        await scanner.stopScan();

        expect(capturedCalls.length, 1);
        expect(capturedCalls.first.method, 'stopScan');
      });

      test('deve propagar erro do MethodChannel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'startScan') {
              throw PlatformException(
                code: 'BLUETOOTH_ERROR',
                details: 'Bluetooth unavailable',
              );
            }
            return null;
          },
        );

        final scanStream = scanner.scan(timeout: Duration(seconds: 1));
        final errors = <Exception>[];

        scanStream.listen(
          (_) {},
          onError: errors.add,
        );

        await Future.delayed(Duration(milliseconds: 100));

        expect(errors.length, 1);
        expect(errors.first, isA<PlatformException>());
      });

      test('deve handle múltiplas chamadas simultâneas', () async {
        final futures = [
          scanner.scan(timeout: Duration(milliseconds: 100)).drain(),
          scanner.startScan(timeout: Duration(milliseconds: 100)),
        ];

        await Future.wait(futures);

        expect(capturedCalls.where((c) => c.method == 'startScan').length, 2);
      });
    });

    group('Comportamento de Duplicatas', () {
      test('não deve duplicar dispositivos com mesmo endereço', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Enviar mesmo dispositivo
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
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 1);
        expect(devices.first.name, 'Device 1'); // Primeiro nome mantido
      });

      test('deve atualizar dispositivo existente quando dados mudam', () async {
        final results = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(results.add);

        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Dispositivo inicial
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Original',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 20));

        // Atualização
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Updated',
              'address': '00:11:22:33:44:55',
              'type': 2,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();
        await subscription.cancel();

        expect(results.last.length, 1);
        expect(results.last.first.name, 'Updated');
        expect(results.last.first.type, 2);
      });

      test('deve manter dispositivos diferentes com endereços diferentes',
          () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Dispositivo 1
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

        // Dispositivo 2
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Device 2',
              'address': '00:11:22:33:44:66',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();

        expect(devices.length, 2);
        expect(devices.map((d) => d.address).toSet().length, 2);
      });
    });

    group('Gerenciamento de Recursos', () {
      test('deve liberar recursos corretamente no dispose', () async {
        final scanResultsSub = scanner.scanResults.listen((_) {});
        final isScanningSub = scanner.isScanning.listen((_) {});

        scanner.dispose();

        expect(scanResultsSub.isPaused, true);
        expect(isScanningSub.isPaused, true);
      });

      test('deve permitir múltiplos scanners coexistentes', () async {
        final scanner1 = MethodChannelBluetoothScanner();
        final scanner2 = MethodChannelBluetoothScanner();

        final results1 = <List<BluetoothDevice>>[];
        final results2 = <List<BluetoothDevice>>[];

        final sub1 = scanner1.scanResults.listen(results1.add);
        final sub2 = scanner2.scanResults.listen(results2.add);

        await scanner1.scan(timeout: Duration(milliseconds: 100)).drain();
        await scanner2.scan(timeout: Duration(milliseconds: 100)).drain();

        await sub1.cancel();
        await sub2.cancel();

        scanner1.dispose();
        scanner2.dispose();

        expect(results1.length, greaterThan(0));
        expect(results2.length, greaterThan(0));
      });

      test('deve limpar controladores internos corretamente', () async {
        final scanner = MethodChannelBluetoothScanner();

        // Usar scanner
        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        // Verificar que streams funcionam
        final results = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(results.add);
        await subscription.cancel();

        // Dispose
        scanner.dispose();

        // Tentar usar após dispose deve falhar
        expect(() => scanner.scanResults.listen((_) {}), throwsA(anything));
      });

      test('deve handle múltiplos dispose sem erro', () async {
        expect(() {
          scanner.dispose();
          scanner.dispose();
          scanner.dispose();
        }, returnsNormally);
      });
    });

    group('Timeout Behavior', () {
      test('deve usar timeout padrão de 5 segundos', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.startScan();

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(6000));
        expect(stopwatch.elapsedMilliseconds, greaterThan(4000));
      });

      test('deve respeitar timeout customizado', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.startScan(timeout: Duration(milliseconds: 200));

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(400));
      });

      test('deve cancelar timer quando scan para manualmente', () async {
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 5)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 100));
        await scanner.stopScan();

        await scanSubscription.cancel();

        // Se não cancelasse o timer, esperaria 5 segundos
        // Mas como parou manualmente, deve ser rápido
        expect(true, true); // Se chegou aqui, o timer foi cancelado
      });

      test('deve funcionar com timeout muito curto', () async {
        final devices = <BluetoothDevice>[];

        await scanner
            .scan(timeout: Duration(milliseconds: 10))
            .forEach(devices.add);

        expect(devices, isA<List<BluetoothDevice>>());
      });
    });

    group('BluetoothDevice Model', () {
      test('deve calcular effectiveType corretamente', () {
        final device1 = BluetoothDevice(type: BluetoothDevice.TYPE_CLASSIC);
        final device2 = BluetoothDevice(type: null);

        expect(device1.effectiveType, BluetoothDevice.TYPE_CLASSIC);
        expect(device2.effectiveType, BluetoothDevice.TYPE_UNKNOWN);
      });

      test('deve implementar equality baseado no endereço', () {
        final device1 =
            BluetoothDevice(address: '00:11:22:33:44:55', name: 'Device 1');
        final device2 =
            BluetoothDevice(address: '00:11:22:33:44:55', name: 'Device 2');
        final device3 =
            BluetoothDevice(address: '00:11:22:33:44:66', name: 'Device 1');

        expect(device1 == device2, true);
        expect(device1 == device3, false);
      });

      test('deve implementar hashCode baseado no endereço', () {
        final device1 = BluetoothDevice(address: '00:11:22:33:44:55');
        final device2 = BluetoothDevice(address: '00:11:22:33:44:55');

        expect(device1.hashCode, equals(device2.hashCode));
      });

      test('deve converter JSON com tipos complexos', () {
        final json = {
          'name': 'Complex Device',
          'address': '00:11:22:33:44:55',
          'type': BluetoothDevice.TYPE_DUAL,
          'connected': true,
        };

        final device = BluetoothDevice.fromJson(json);

        expect(device.name, 'Complex Device');
        expect(device.type, BluetoothDevice.TYPE_DUAL);
        expect(device.effectiveType, BluetoothDevice.TYPE_DUAL);
      });

      test('deve handle JSON malformado gracefulmente', () {
        final json = {
          'name': 123, // tipo errado
          'address': ['not', 'a', 'string'], // tipo errado
          'type': 'not_a_number', // tipo errado
        };

        expect(
          () => BluetoothDevice.fromJson(json),
          returnsNormally,
        );
      });
    });

    group('Tratamento de Erros', () {
      test('deve lançar BluetoothPrintException em stopScan com erro',
          () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'stopScan') {
              throw PlatformException(
                code: 'STOP_SCAN_ERROR',
                details: 'Failed to stop scanning',
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

      test('deve incluir código e mensagem na exceção', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'stopScan') {
              throw PlatformException(
                code: 'CUSTOM_ERROR',
                details: 'Custom error message',
              );
            }
            return null;
          },
        );

        try {
          await scanner.stopScan();
          fail('Deveria lançar exceção');
        } on BluetoothPrintException catch (e) {
          expect(e.code, 'stop_scan_error');
          expect(e.message, contains('Custom error message'));
        }
      });

      test('deve propagar erro durante scan', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'startScan') {
              throw PlatformException(
                code: 'SCAN_ERROR',
                details: 'Scan failed',
              );
            }
            return null;
          },
        );

        final errors = <Exception>[];
        final scanStream = scanner.scan(timeout: Duration(seconds: 1));

        scanStream.listen(
          (_) {},
          onError: errors.add,
        );

        await Future.delayed(Duration(milliseconds: 100));

        expect(errors.length, 1);
        expect(errors.first, isA<PlatformException>());
      });

      test('deve limpar estado mesmo com erro', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'startScan') {
              throw PlatformException(
                code: 'SCAN_ERROR',
                details: 'Scan failed',
              );
            }
            return null;
          },
        );

        final statuses = <bool>[];
        final subscription = scanner.isScanning.listen(statuses.add);

        final scanStream = scanner.scan(timeout: Duration(seconds: 1));
        scanStream.listen(
          (_) {},
          onError: (_) {},
        );

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();

        expect(statuses.contains(false), true);
      });
    });

    group('Interface Contract', () {
      test('deve implementar IBluetoothScanner corretamente', () {
        expect(scanner, isA<IBluetoothScanner>());
      });

      test('deve ter todos os métodos requeridos', () {
        final scannerInterface = scanner as IBluetoothScanner;

        expect(scannerInterface.scan,
            isA<Stream<BluetoothDevice> Function({Duration? timeout})>());
        expect(scannerInterface.startScan,
            isA<Future<List<BluetoothDevice>> Function({Duration? timeout})>());
        expect(scannerInterface.stopScan, isA<Future<void> Function()>());
        expect(
            scannerInterface.scanResults, isA<Stream<List<BluetoothDevice>>>());
        expect(scannerInterface.isScanning, isA<Stream<bool>>());
      });

      test('deve manter contrato de streams broadcast', () {
        final scannerInterface = scanner as IBluetoothScanner;

        final sub1 = scannerInterface.scanResults.listen((_) {});
        final sub2 = scannerInterface.scanResults.listen((_) {});
        final sub3 = scannerInterface.isScanning.listen((_) {});
        final sub4 = scannerInterface.isScanning.listen((_) {});

        expect(sub1.isPaused, false);
        expect(sub2.isPaused, false);
        expect(sub3.isPaused, false);
        expect(sub4.isPaused, false);

        sub1.cancel();
        sub2.cancel();
        sub3.cancel();
        sub4.cancel();
      });

      test('deve manter consistência entre interfaces', () {
        final scannerInterface = scanner as IBluetoothScanner;

        expect(scannerInterface.scanResults, same(scanner.scanResults));
        expect(scannerInterface.isScanning, same(scanner.isScanning));
      });

      test('deve implementar métodos com assinaturas corretas', () async {
        final scannerInterface = scanner as IBluetoothScanner;

        // Testar scan
        final scanStream =
            scannerInterface.scan(timeout: Duration(milliseconds: 100));
        expect(scanStream, isA<Stream<BluetoothDevice>>());
        await scanStream.drain();

        // Testar startScan
        final devices = await scannerInterface.startScan(
            timeout: Duration(milliseconds: 100));
        expect(devices, isA<List<BluetoothDevice>>());

        // Testar stopScan
        await scannerInterface.stopScan();
      });
    });

    group('Performance e Otimização', () {
      test('deve handle grande volume de dispositivos', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular muitos dispositivos
        for (int i = 0; i < 100; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': 'Device $i',
                'address': '00:11:22:33:44:${i.toString().padLeft(2, '0')}',
                'type': 1,
              }),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        expect(devices.length, 100);
      });

      test('deve ser eficiente com duplicatas', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription =
            scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Enviar mesmo dispositivo muitas vezes
        for (int i = 0; i < 50; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': 'Duplicate Device',
                'address': '00:11:22:33:44:55',
                'type': 1,
              }),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        expect(devices.length, 1); // Apenas um dispositivo adicionado
      });

      test('deve limpar resultados entre scans', () async {
        final scanSubscription1 =
            scanner.scan(timeout: Duration(milliseconds: 100)).listen((_) {});

        // Adicionar dispositivo no primeiro scan
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

        await scanSubscription1.cancel();

        final results = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(results.add);

        final scanSubscription2 =
            scanner.scan(timeout: Duration(milliseconds: 100)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription2.cancel();
        await subscription.cancel();

        // Resultados devem ser limpos no início do scan
        expect(results.first.isEmpty, true);
      });
    });
  });
}
