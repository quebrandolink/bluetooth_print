import 'dart:async';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:flutter/services.dart';

import 'bluetooth_print_model.dart';

class BluetoothScanner {
  static const MethodChannel _channel =
      MethodChannel('bluetooth_print/methods');

  final StreamController<bool> _isScanningController =
      StreamController.broadcast();
  final StreamController<List<BluetoothDevice>> _scanResultsController =
      StreamController.broadcast();

  bool _isScanning = false;
  List<BluetoothDevice> _scanResults = [];

  Completer<void>? _stopScanCompleter;

  // Getter para quem quiser escutar se está escaneando ou não
  Stream<bool> get isScanning => _isScanningController.stream;

  // Getter da lista de dispositivos encontrados
  Stream<List<BluetoothDevice>> get scanResults =>
      _scanResultsController.stream;

  // Método para iniciar o escaneamento
  Stream<BluetoothDevice> scan({
    Duration? timeout,
  }) async* {
    if (_isScanning) {
      throw Exception('Já existe um escaneamento em andamento.');
    }

    _isScanning = true;
    _isScanningController.add(true);
    _scanResults = [];
    _scanResultsController.add(_scanResults);

    _stopScanCompleter = Completer<void>();

    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        stopScan(); // Para automaticamente após o timeout
      });
    }

    try {
      await _channel.invokeMethod('startScan');
    } catch (e) {
      stopScan();
      throw e;
    }

    final stream = BluetoothPrint.instance.methodStream
        .where((m) => m.method == "ScanResult")
        .takeWhile((_) => !_stopScanCompleter!.isCompleted)
        .map((m) {
      final device =
          BluetoothDevice.fromJson(Map<String, dynamic>.from(m.arguments));
      final index = _scanResults.indexWhere((d) => d.address == device.address);
      if (index != -1) {
        _scanResults[index] = device;
      } else {
        _scanResults.add(device);
      }
      _scanResultsController.add(List.from(_scanResults));
      return device;
    });

    yield* stream;

    timeoutTimer?.cancel(); // Se finalizou antes do tempo, cancela o timer
  }

  // Inicia e aguarda o término do escaneamento
  Future<List<BluetoothDevice>> startScan({Duration? timeout}) async {
    await scan(timeout: timeout).drain();
    return _scanResults;
  }

  // Método para parar o escaneamento
  Future<void> stopScan() async {
    if (!_isScanning) return;

    _isScanning = false;
    _isScanningController.add(false);
    await _channel.invokeMethod('stopScan');
    _stopScanCompleter?.complete();
  }
}
