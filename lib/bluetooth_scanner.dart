// import 'dart:async';
// import 'package:bluetooth_print/bluetooth_print.dart';
// import 'package:bluetooth_print/bluetooth_print_exception.dart';
// import 'package:flutter/services.dart';

// import 'bluetooth_print_model.dart';

// /// Classe responsável por escanear dispositivos Bluetooth compatíveis com impressão
// ///
// /// Gerencia todo o ciclo de vida do escaneamento:
// /// - Início/parada do escaneamento
// /// - Agregação de resultados
// /// - Timeout automático
// /// - Notificação de estado
// class BluetoothScanner {
//   /// Canal de comunicação com a plataforma nativa
//   static const MethodChannel _channel =
//       MethodChannel('bluetooth_print/methods');

//   /// Controlador para o stream de estado de escaneamento
//   final StreamController<bool> _isScanningController =
//       StreamController<bool>.broadcast();

//   /// Controlador para o stream de resultados do escaneamento
//   final StreamController<List<BluetoothDevice>> _scanResultsController =
//       StreamController<List<BluetoothDevice>>.broadcast();

//   /// Flag que indica se o escaneamento está ativo
//   bool _isScanning = false;

//   /// Lista mutável de dispositivos encontrados
//   List<BluetoothDevice> _scanResults = [];

//   /// Completer para controle do término do escaneamento
//   Completer<void>? _stopScanCompleter;

//   /// Stream que emite o estado atual do escaneamento
//   ///
//   /// Retorna `true` quando o escaneamento está ativo e `false` quando inativo
//   Stream<bool> get isScanning => _isScanningController.stream;

//   /// Stream que emite a lista acumulada de dispositivos encontrados
//   ///
//   /// A lista é atualizada sempre que um novo dispositivo é descoberto
//   Stream<List<BluetoothDevice>> get scanResults =>
//       _scanResultsController.stream;

//   /// Inicia o escaneamento de dispositivos Bluetooth
//   ///
//   /// [timeout]: Duração opcional após a qual o escaneamento será automaticamente
//   ///           interrompido. Se null, o escaneamento continua até ser parado manualmente.
//   ///
//   /// Retorna um [Stream] que emite cada dispositivo conforme é descoberto.
//   ///
//   /// Lança [PlatformException] se ocorrer um erro na plataforma nativa.
//   Stream<BluetoothDevice> scan({Duration? timeout}) async* {
//     if (_isScanning) {
//       await stopScan();
//       throw StateError('Já existe um escaneamento em andamento');
//     }

//     _isScanning = true;
//     _isScanningController.add(true);
//     _scanResults.clear();
//     _scanResultsController.add(_scanResults);

//     _stopScanCompleter = Completer<void>();

//     try {
//       // Verifica se o Bluetooth está ativado
//       if (!(await BluetoothPrint.instance.isOn)) {
//         throw BluetoothPrintException(
//             'bluetooth_off', 'Bluetooth está desligado');
//       }

//       await _channel.invokeMethod('startScan');
//     } on PlatformException catch (e) {
//       await stopScan();
//       throw BluetoothPrintException(e.code, e.message ?? "Erro ao escanear");
//     } catch (e) {
//       await stopScan();
//       rethrow;
//     }

//     final stream = BluetoothPrint.instance.methodStream
//         .where((m) => m.method == "ScanResult")
//         .takeWhile((_) => !_stopScanCompleter!.isCompleted)
//         .map((m) {
//           print("************ scanResults: ${m.arguments}");
//           try {
//             final device = BluetoothDevice.fromJson(
//                 Map<String, dynamic>.from(m.arguments));

//             // Filtra apenas dispositivos com nome (impressoras geralmente têm nome)
//             if (device.name == null || device.name!.isEmpty) return null;

//             final index =
//                 _scanResults.indexWhere((d) => d.address == device.address);
//             if (index != -1) {
//               _scanResults[index] = device;
//             } else {
//               _scanResults.add(device);
//             }
//             _scanResultsController.add([..._scanResults]);
//             return device;
//           } catch (e) {
//             return null;
//           }
//         })
//         .where((device) => device != null)
//         .cast<BluetoothDevice>();

//     yield* stream.timeout(
//       timeout ?? const Duration(seconds: 15),
//       onTimeout: (sink) {
//         stopScan();
//         sink.close();
//       },
//     );
//   }

//   /// Inicia o escaneamento e retorna uma Future com todos os dispositivos encontrados
//   ///
//   /// [timeout]: Tempo máximo de escaneamento (padrão: 15 segundos)
//   ///
//   /// Retorna uma [Future] que completa com a lista completa de dispositivos
//   /// quando o escaneamento terminar (por timeout ou parada manual).
//   Future<List<BluetoothDevice>> startScan(
//       {Duration? timeout = const Duration(seconds: 15)}) async {
//     await scan(timeout: timeout).drain();
//     return _scanResults;
//   }

//   /// Interrompe o escaneamento em andamento
//   ///
//   /// Não faz nada se nenhum escaneamento estiver ativo.
//   ///
//   /// Retorna uma [Future] que completa quando o escaneamento for totalmente
//   /// interrompido.
//   Future<void> stopScan() async {
//     if (!_isScanning) return;

//     try {
//       _isScanning = false;
//       _isScanningController.add(false);
//       await _channel.invokeMethod('stopScan');
//       _stopScanCompleter?.complete();
//     } on PlatformException catch (e) {
//       throw BluetoothPrintException(
//           e.code, e.message ?? "Erro ao parar escaneamento");
//     }
//   }

//   /// Libera os recursos utilizados pelo scanner
//   ///
//   /// Deve ser chamado quando o scanner não for mais necessário
//   void dispose() {
//     _isScanningController.close();
//     _scanResultsController.close();
//   }
// }
