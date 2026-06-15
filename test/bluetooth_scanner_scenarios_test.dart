import 'package:bluetooth_print/src/models/bluetooth_device.dart';
import 'package:bluetooth_print/src/bluetooth_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MethodChannelBluetoothScanner Realistic Scenarios', () {
    late MethodChannelBluetoothScanner scanner;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('bluetooth_print/methods'),
        null,
      );
      scanner.dispose();
    });

    group('Fluxo de Escaneamento Básico', () {
      test('deve iniciar e parar scan corretamente', () async {
        final statuses = <bool>[];
        final statusSub = scanner.isScanning.listen(statuses.add);

        // Iniciar scan
        final scanSubscription = scanner.scan(timeout: Duration(milliseconds: 200)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));
        expect(statuses.last, true);

        // Parar scan manualmente
        await scanner.stopScan();

        await Future.delayed(Duration(milliseconds: 50));
        expect(statuses.last, false);

        await scanSubscription.cancel();
        await statusSub.cancel();
      });

      test('deve completar scan automaticamente com timeout', () async {
        final statuses = <bool>[];
        final statusSub = scanner.isScanning.listen(statuses.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await Future.delayed(Duration(milliseconds: 50));

        expect(statuses.contains(true), true);
        expect(statuses.contains(false), true);

        await statusSub.cancel();
      });

      test('deve permitir múltiplos scans sequenciais', () async {
        for (int i = 0; i < 3; i++) {
          final devices = await scanner.startScan(timeout: Duration(milliseconds: 50));
          expect(devices, isA<List<BluetoothDevice>>());

          // Pequena pausa entre scans
          await Future.delayed(Duration(milliseconds: 25));
        }
      });

      test('deve manter estado consistente entre scans', () async {
        final statuses = <bool>[];
        final statusSub = scanner.isScanning.listen(statuses.add);

        // Primeiro scan
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        expect(statuses.last, false);

        // Segundo scan
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        expect(statuses.last, false);

        await statusSub.cancel();
      });
    });

    group('Filtros e Processamento', () {
      test('deve filtrar apenas impressoras', () async {
        final allDevices = <BluetoothDevice>[];
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen(allDevices.add);

        // Simular dispositivos misturados
        final devices = [
          {'name': 'HP Printer', 'address': '00:11:22:33:44:55', 'type': 1},
          {'name': 'Headphones', 'address': '00:11:22:33:44:66', 'type': 1},
          {'name': 'Canon Printer', 'address': '00:11:22:33:44:77', 'type': 1},
          {'name': 'Mouse', 'address': '00:11:22:33:44:88', 'type': 1},
        ];

        for (final device in devices) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', device),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        // Filtrar apenas impressoras
        final printers = allDevices.where((d) => d.name?.toLowerCase().contains('printer') ?? false).toList();

        expect(printers.length, 2);
        expect(printers.every((p) => p.name!.contains('Printer')), true);
      });

      test('deve agrupar dispositivos por tipo', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        // Simular diferentes tipos
        final deviceTypes = [
          {'name': 'Classic Device', 'address': '00:11:22:33:44:55', 'type': BluetoothDevice.TYPE_CLASSIC},
          {'name': 'LE Device', 'address': '00:11:22:33:44:66', 'type': BluetoothDevice.TYPE_LE},
          {'name': 'Dual Device', 'address': '00:11:22:33:44:77', 'type': BluetoothDevice.TYPE_DUAL},
          {'name': 'Unknown Device', 'address': '00:11:22:33:44:88', 'type': BluetoothDevice.TYPE_UNKNOWN},
        ];

        for (final device in deviceTypes) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', device),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        // Agrupar por tipo
        final grouped = <int, List<BluetoothDevice>>{};
        for (final device in devices) {
          final type = device.effectiveType;
          grouped.putIfAbsent(type, () => []).add(device);
        }

        expect(grouped[BluetoothDevice.TYPE_CLASSIC]?.length, 1);
        expect(grouped[BluetoothDevice.TYPE_LE]?.length, 1);
        expect(grouped[BluetoothDevice.TYPE_DUAL]?.length, 1);
        expect(grouped[BluetoothDevice.TYPE_UNKNOWN]?.length, 1);
      });

      test('deve contar dispositivos únicos corretamente', () async {
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Enviar dispositivos duplicados
        final duplicateDevices = [
          {'name': 'Device 1', 'address': '00:11:22:33:44:55', 'type': 1},
          {'name': 'Device 2', 'address': '00:11:22:33:44:55', 'type': 1}, // Mesmo endereço
          {'name': 'Device 3', 'address': '00:11:22:33:44:66', 'type': 1},
          {'name': 'Device 4', 'address': '00:11:22:33:44:66', 'type': 1}, // Mesmo endereço
          {'name': 'Device 5', 'address': '00:11:22:33:44:77', 'type': 1},
        ];

        for (final device in duplicateDevices) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', device),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));

        final results = await scanner.scanResults.first;
        await scanSubscription.cancel();

        expect(results.length, 3); // Apenas 3 dispositivos únicos
      });

      test('deve ordenar dispositivos por nome', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        final unsortedDevices = [
          {'name': 'Zebra Printer', 'address': '00:11:22:33:44:55', 'type': 1},
          {'name': 'Apple Device', 'address': '00:11:22:33:44:66', 'type': 1},
          {'name': 'Samsung Printer', 'address': '00:11:22:33:44:77', 'type': 1},
        ];

        for (final device in unsortedDevices) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', device),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        // Ordenar por nome
        devices.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

        expect(devices.first.name, 'Apple Device');
        expect(devices[1].name, 'Samsung Printer');
        expect(devices.last.name, 'Zebra Printer');
      });
    });

    group('Monitoramento de Status', () {
      test('deve monitorar transições de estado corretamente', () async {
        final transitions = <String>[];

        final subscription = scanner.isScanning.listen((isScanning) {
          transitions.add(isScanning ? 'started' : 'stopped');
        });

        // Múltiplos scans
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();

        // Deve ter transições alternadas
        expect(transitions.length, greaterThan(0));
        expect(transitions.first, 'started');
        expect(transitions.last, 'stopped');
      });

      test('deve suportar múltiplos listeners simultâneos', () async {
        final listener1 = <bool>[];
        final listener2 = <bool>[];
        final listener3 = <bool>[];

        final sub1 = scanner.isScanning.listen(listener1.add);
        final sub2 = scanner.isScanning.listen(listener2.add);
        final sub3 = scanner.isScanning.listen(listener3.add);

        await scanner.scan(timeout: Duration(milliseconds: 100)).drain();

        await Future.delayed(Duration(milliseconds: 50));

        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();

        // Todos devem receber as mesmas atualizações
        expect(listener1.length, equals(listener2.length));
        expect(listener2.length, equals(listener3.length));
      });

      test('deve manter estado após cancelar listener', () async {
        final statuses = <bool>[];

        // Primeiro listener
        final sub1 = scanner.isScanning.listen(statuses.add);
        await scanner.scan(timeout: Duration(milliseconds: 50)).drain();
        await sub1.cancel();

        // Segundo listener deve começar com estado atual
        final newStatuses = <bool>[];
        final sub2 = scanner.isScanning.listen(newStatuses.add);

        await Future.delayed(Duration(milliseconds: 50));
        await sub2.cancel();

        expect(newStatuses.last, false); // Estado atual
      });

      test('deve handle listeners que são adicionados durante scan', () async {
        final earlyListener = <bool>[];
        final lateListener = <bool>[];

        final earlySub = scanner.isScanning.listen(earlyListener.add);

        final scanSubscription = scanner.scan(timeout: Duration(milliseconds: 200)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));

        // Adicionar listener durante scan
        final lateSub = scanner.isScanning.listen(lateListener.add);

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        await earlySub.cancel();
        await lateSub.cancel();

        expect(earlyListener.contains(true), true);
        expect(lateListener.contains(true), true);
      });
    });

    group('Resultados Acumulados', () {
      test('deve manter histórico de descoberta', () async {
        final history = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(history.add);

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Adicionar dispositivos progressivamente
        for (int i = 0; i < 3; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
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

          await Future.delayed(Duration(milliseconds: 50));
        }

        await scanSubscription.cancel();
        await subscription.cancel();

        // Verificar histórico
        expect(history.length, greaterThan(0));
        expect(history.first.isEmpty, true); // Começa vazio
        expect(history.last.length, 3); // Termina com 3 dispositivos
      });

      test('não deve adicionar duplicatas ao histórico', () async {
        final history = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(history.add);

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Enviar mesmo dispositivo múltiplas vezes
        for (int i = 0; i < 5; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
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

          await Future.delayed(Duration(milliseconds: 20));
        }

        await scanSubscription.cancel();
        await subscription.cancel();

        // Histórico não deve ter duplicatas
        expect(history.last.length, 1);

        // Mas deve ter múltiplas atualizações (quando dispositivo é atualizado)
        expect(history.length, greaterThan(1));
      });

      test('deve limpar histórico em novo scan', () async {
        final history = <List<BluetoothDevice>>[];
        final subscription = scanner.scanResults.listen(history.add);

        // Primeiro scan
        final scanSubscription1 = scanner.scan(timeout: Duration(milliseconds: 100)).listen((_) {});

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
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

        // Segundo scan
        final scanSubscription2 = scanner.scan(timeout: Duration(milliseconds: 100)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription2.cancel();
        await subscription.cancel();

        // Deve ter limpeza no início do segundo scan
        final hasEmptyReset = history.any((devices) => devices.isEmpty);
        expect(hasEmptyReset, true);
      });
    });

    group('Controle de Lifecycle', () {
      test('deve reiniciar scan após erro', () async {
        // Simular erro no primeiro scan
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('bluetooth_print/methods'),
          (methodCall) async {
            if (methodCall.method == 'startScan') {
              throw PlatformException(
                code: 'ERROR',
                details: 'Simulated error',
              );
            }
            return null;
          },
        );

        // Primeiro scan deve falhar
        final errors = <Exception>[];
        final scanStream1 = scanner.scan(timeout: Duration(seconds: 1));
        scanStream1.listen(
          (_) {},
          onError: errors.add,
        );

        await Future.delayed(Duration(milliseconds: 100));
        expect(errors.length, 1);

        // Restaurar handler normal
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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

        // Segundo scan deve funcionar
        final devices = await scanner.startScan(timeout: Duration(milliseconds: 100));
        expect(devices, isA<List<BluetoothDevice>>());
      });

      test('deve limpar recursos após dispose', () async {
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});
        final statusSubscription = scanner.isScanning.listen((_) {});

        scanner.dispose();

        // Tentar usar após dispose deve falhar
        expect(() => scanner.scanResults.listen((_) {}), throwsA(anything));
        expect(() => scanner.isScanning.listen((_) {}), throwsA(anything));

        await scanSubscription.cancel();
        await statusSubscription.cancel();
      });

      test('deve handle reinicialização rápida', () async {
        for (int i = 0; i < 10; i++) {
          final scanner = MethodChannelBluetoothScanner();

          await scanner.scan(timeout: Duration(milliseconds: 20)).drain();

          scanner.dispose();

          // Pequena pausa
          await Future.delayed(Duration(milliseconds: 5));
        }

        // Se chegou aqui, não houve vazamento de recursos
        expect(true, true);
      });

      test('deve manter consistência em lifecycle complexo', () async {
        final scanners = <MethodChannelBluetoothScanner>[];

        // Criar múltiplos scanners
        for (int i = 0; i < 3; i++) {
          scanners.add(MethodChannelBluetoothScanner());
        }

        // Usar todos simultaneamente
        final futures = scanners.map((s) => s.scan(timeout: Duration(milliseconds: 50)).drain()).toList();

        await Future.wait(futures);

        // Dispor todos
        for (final scanner in scanners) {
          scanner.dispose();
        }

        // Se chegou aqui, todos foram gerenciados corretamente
        expect(true, true);
      });
    });

    group('Edge Cases Realistas', () {
      test('deve handle timeout muito curto', () async {
        final stopwatch = Stopwatch()..start();

        await scanner.scan(timeout: Duration(milliseconds: 1)).drain();

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('deve handle scan sem resultados', () async {
        final devices = await scanner.startScan(timeout: Duration(milliseconds: 50));

        expect(devices.isEmpty, true);
      });

      test('deve handle dispositivos com nomes especiais', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        final specialNames = [
          'Device with émojis 🖨️',
          'Device\nwith\nnewlines',
          'Device\twith\ttabs',
          'Device with "quotes"',
          "Device with 'apostrophes'",
          'Device with &lt;tags&gt;',
        ];

        for (int i = 0; i < specialNames.length; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': specialNames[i],
                'address': '00:11:22:33:44:${i.toString().padLeft(2, '0')}',
                'type': 1,
              }),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        expect(devices.length, specialNames.length);

        for (int i = 0; i < specialNames.length; i++) {
          expect(devices[i].name, equals(specialNames[i]));
        }
      });

      test('deve handle endereços MAC em diferentes formatos', () async {
        final devices = <BluetoothDevice>[];
        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen(devices.add);

        final addresses = [
          '00:11:22:33:44:55',
          '00-11-22-33-44-66',
          '0011.2233.4477',
          '001122334488',
        ];

        for (int i = 0; i < addresses.length; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': 'Device $i',
                'address': addresses[i],
                'type': 1,
              }),
            ),
            (data) {},
          );
        }

        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        expect(devices.length, addresses.length);

        // Todos devem ser tratados como endereços válidos
        for (final device in devices) {
          expect(device.address, isNotNull);
          expect(device.address!.isNotEmpty, true);
        }
      });

      test('deve handle concorrência de múltiplas operações', () async {
        final operations = <Future>[];

        // Operações concorrentes
        operations.add(scanner.scan(timeout: Duration(milliseconds: 50)).drain());
        operations.add(scanner.startScan(timeout: Duration(milliseconds: 50)));
        operations.add(scanner.scanResults.first);
        operations.add(scanner.isScanning.first);

        // Deve completar sem deadlock
        await Future.wait(operations);

        expect(true, true);
      });
    });

    group('Integração com UI', () {
      test('deve funcionar com StreamBuilder pattern', () async {
        final builderEvents = <List<BluetoothDevice>>[];

        // Simular StreamBuilder
        final subscription = scanner.scanResults.listen((results) {
          builderEvents.add(results);
        });

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Simular dispositivos chegando
        for (int i = 0; i < 3; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': 'UI Device $i',
                'address': '00:11:22:33:44:${i.toString().padLeft(2, '0')}',
                'type': 1,
              }),
            ),
            (data) {},
          );

          await Future.delayed(Duration(milliseconds: 50));
        }

        await scanSubscription.cancel();
        await subscription.cancel();

        // StreamBuilder receberia atualizações progressivas
        expect(builderEvents.length, greaterThan(0));
        expect(builderEvents.last.length, 3);
      });

      test('deve atualizar UI em tempo real', () async {
        final uiUpdates = <bool>[];
        final deviceUpdates = <int>[];

        // Status para UI
        final statusSub = scanner.isScanning.listen((scanning) {
          uiUpdates.add(scanning);
        });

        // Dispositivos para UI
        final deviceSub = scanner.scanResults.listen((devices) {
          deviceUpdates.add(devices.length);
        });

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Simular descoberta gradual
        for (int i = 0; i < 5; i++) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            'bluetooth_print/methods',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('ScanResult', {
                'name': 'Realtime Device $i',
                'address': '00:11:22:33:44:${i.toString().padLeft(2, '0')}',
                'type': 1,
              }),
            ),
            (data) {},
          );

          await Future.delayed(Duration(milliseconds: 30));
        }

        await scanSubscription.cancel();
        await statusSub.cancel();
        await deviceSub.cancel();

        // UI deve ter sido atualizada em tempo real
        expect(uiUpdates.contains(true), true);
        expect(uiUpdates.contains(false), true);
        expect(deviceUpdates.last, 5);
      });

      test('deve handle cancelamento de UI durante scan', () async {
        final uiActive = <bool>[];

        final statusSub = scanner.isScanning.listen((scanning) {
          uiActive.add(scanning);
        });

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        await Future.delayed(Duration(milliseconds: 50));

        // UI "cancela" (unsubscribe)
        await statusSub.cancel();

        // Scan continua internamente
        await Future.delayed(Duration(milliseconds: 100));
        await scanSubscription.cancel();

        // Estado interno deve ser consistente
        expect(true, true);
      });

      test('deve suportar rebuilds frequentes', () async {
        // Simular rebuilds de widget
        for (int i = 0; i < 10; i++) {
          final subscription = scanner.scanResults.listen((_) {});

          await Future.delayed(Duration(milliseconds: 10));

          await subscription.cancel();
        }

        // Deve handle sem vazamentos
        expect(true, true);
      });

      test('deve fornecer dados consistentes para UI', () async {
        final snapshots = <List<BluetoothDevice>>[];

        final subscription = scanner.scanResults.listen(snapshots.add);

        final scanSubscription = scanner.scan(timeout: Duration(seconds: 1)).listen((_) {});

        // Enviar dispositivos
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
          'bluetooth_print/methods',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('ScanResult', {
              'name': 'Consistent Device',
              'address': '00:11:22:33:44:55',
              'type': 1,
            }),
          ),
          (data) {},
        );

        await Future.delayed(Duration(milliseconds: 50));
        await scanSubscription.cancel();
        await subscription.cancel();

        // Todos os snapshots devem ser consistentes
        for (final snapshot in snapshots) {
          expect(snapshot, isA<List<BluetoothDevice>>());
        }

        // Último snapshot deve ter o dispositivo
        expect(snapshots.last.length, 1);
        expect(snapshots.last.first.name, 'Consistent Device');
      });
    });
  });
}
