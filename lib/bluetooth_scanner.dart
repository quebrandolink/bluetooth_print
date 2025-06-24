import 'dart:async';

import 'package:bluetooth_print/bluetooth_print_exception.dart';
import 'package:flutter/services.dart';
import 'bluetooth_print_model.dart';

/// Interface para escaneamento Bluetooth
abstract class IBluetoothScanner {
  Stream<BluetoothDevice> scan({Duration timeout});
  Future<List<BluetoothDevice>> startScan({Duration timeout});
  Future<void> stopScan();
  Stream<List<BluetoothDevice>> get scanResults;
  Stream<bool> get isScanning;
}

/// Implementação padrão usando MethodChannel para escanear dispositivos Bluetooth
class MethodChannelBluetoothScanner implements IBluetoothScanner {
  static const MethodChannel _channel =
      MethodChannel('bluetooth_print/methods');
  /* static const EventChannel _eventChannel =
      EventChannel('bluetooth_print/state'); */

  final StreamController<List<BluetoothDevice>> _scanResultsController =
      StreamController.broadcast();
  final StreamController<bool> _isScanningController =
      StreamController.broadcast();
  List<BluetoothDevice> _results = [];
  bool _scanning = false;

  Stream<List<BluetoothDevice>> get scanResults =>
      _scanResultsController.stream;
  Stream<bool> get isScanning => _isScanningController.stream;

  final StreamController<void> _stopScanController =
      StreamController<void>.broadcast();
  final StreamController<MethodCall> _methodCallController =
      StreamController.broadcast();

  MethodChannelBluetoothScanner() {
    _channel.setMethodCallHandler((call) async {
      _methodCallController.add(call);
    });
  }

  @override
  Stream<BluetoothDevice> scan(
      {Duration timeout = const Duration(seconds: 5)}) {
    final controller = StreamController<BluetoothDevice>();

    if (_scanning) {
      controller.addError(Exception('Escaneamento já em andamento.'));
      return controller.stream;
    }

    _scanning = true;
    _isScanningController.add(true);
    _results.clear();
    _scanResultsController.add([]);

    final sub = _methodCallController.stream
        .where((m) => m.method == 'ScanResult')
        .map((m) =>
            BluetoothDevice.fromJson(Map<String, dynamic>.from(m.arguments)))
        .listen((device) {
      final addr = device.address?.toUpperCase().trim();
      if (addr == null || addr.isEmpty) return;
      final index =
          _results.indexWhere((e) => e.address?.toUpperCase().trim() == addr);
      if (index == -1) {
        _results.add(device);
        _scanResultsController.add(List.from(_results));
        controller.add(device);
      } else if (_results[index].name != device.name ||
          _results[index].type != device.type) {
        _results[index] = device;
        _scanResultsController.add(List.from(_results));
      }
    });

    _channel.invokeMethod('startScan').catchError((e) {
      _stopScan();
      controller.addError(e);
    });

    Timer? timer = Timer(timeout, () {
      _stopScan();
      controller.close();
    });

    _stopScanController.stream.first.then((_) {
      timer.cancel();
      controller.close();
    });

    controller.onCancel = () {
      sub.cancel();
      timer.cancel();
      _stopScan();
    };

    return controller.stream;
  }

  @override
  Future<List<BluetoothDevice>> startScan(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <BluetoothDevice>[];
    await scan(timeout: timeout).forEach(devices.add);
    return devices;
  }

  @override
  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (e) {
      throw BluetoothPrintException(
          'stop_scan_error', 'Erro ao parar escaneamento: $e');
    } finally {
      _stopScan();
    }
  }

  void _stopScan() {
    if (_scanning) {
      _scanning = false;
      _isScanningController.add(false);
      _stopScanController.add(null);
    }
  }

  void dispose() {
    _scanResultsController.close();
    _isScanningController.close();
    _stopScanController.close();
    _methodCallController.close();
  }
}
