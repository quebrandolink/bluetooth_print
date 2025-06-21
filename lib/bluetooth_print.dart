import 'dart:async';

import 'package:flutter/services.dart';

import 'bluetooth_print_model.dart';

class BluetoothPrint {
  static const String NAMESPACE = 'bluetooth_print';
  static const int CONNECTED = 1;
  static const int DISCONNECTED = 0;

  static const MethodChannel _channel =
      const MethodChannel('$NAMESPACE/methods');
  static const EventChannel _stateChannel =
      const EventChannel('$NAMESPACE/state');

  Stream<MethodCall> get _methodStream => _methodStreamController.stream;
  final StreamController<MethodCall> _methodStreamController =
      StreamController.broadcast();

  BluetoothPrint._() {
    _channel.setMethodCallHandler((MethodCall call) async {
      _methodStreamController.add(call);
    });
  }

  static final BluetoothPrint _instance = BluetoothPrint._();

  static BluetoothPrint get instance => _instance;

  Future<bool> get isAvailable async =>
      await _channel.invokeMethod('isAvailable').then<bool>((d) => d);

  Future<bool> get isOn async =>
      await _channel.invokeMethod('isOn').then<bool>((d) => d);

  Future<bool?> get isConnected async =>
      await _channel.invokeMethod('isConnected');

  final StreamController<bool> _isScanningController =
      StreamController<bool>.broadcast();
  bool _isScanningValue = false;

  Stream<bool> get isScanning => _isScanningController.stream;

  final StreamController<List<BluetoothDevice>> _scanResultsController =
      StreamController<List<BluetoothDevice>>.broadcast();
  List<BluetoothDevice> _scanResultsValue = [];

  Stream<List<BluetoothDevice>> get scanResults =>
      _scanResultsController.stream;

  final StreamController<void> _stopScanController =
      StreamController<void>.broadcast();

  /// Gets the current state of the Bluetooth module
  Stream<BluetoothPrintStatus> get state async* {
    final int stateCode = await _channel.invokeMethod('state');
    yield _getBluetoothStatus(stateCode);

    /* yield await _channel
        .invokeMethod('state')
        .then((s) => _getBluetoothStatus(s as int)); */
    yield* _stateChannel
        .receiveBroadcastStream()
        .map((s) => _getBluetoothStatus(s as int));
  }

  BluetoothPrintStatus _getBluetoothStatus(int state) {
    switch (state) {
      case 10:
        return BluetoothPrintStatus.off;
      case 11:
        return BluetoothPrintStatus.turningOn;
      case 12:
        return BluetoothPrintStatus.on;
      case 13:
        return BluetoothPrintStatus.turningOff;
      case 1:
        return BluetoothPrintStatus.connected;
      case 0:
        return BluetoothPrintStatus.disconnected;
      default:
        return BluetoothPrintStatus.unknown;
    }
  }

  /// Starts a scan for Bluetooth Low Energy devices
  /// Timeout closes the stream after a specified [Duration]
  Stream<BluetoothDevice> scan(
      {Duration timeout = const Duration(seconds: 5)}) {
    final scanStreamController = StreamController<BluetoothDevice>();

    if (_isScanningValue) {
      scanStreamController.addError(Exception('Outro scan está em progresso.'));
      return scanStreamController.stream;
    }

    _isScanningValue = true;
    _isScanningController.add(_isScanningValue);
    _scanResultsValue = [];
    _scanResultsController.add(_scanResultsValue);

    final subscription = _methodStream
        .where((m) => m.method == "ScanResult")
        .map((m) => Map<String, dynamic>.from(m.arguments as Map))
        .listen((map) {
      final device = BluetoothDevice.fromJson(map);

      // Improved duplicate detection
      final normalizedAddress = device.address?.toUpperCase().trim();
      if (normalizedAddress == null || normalizedAddress.isEmpty) {
        return; // Skip devices with invalid addresses
      }

      final index = _scanResultsValue.indexWhere(
          (e) => e.address?.toUpperCase().trim() == normalizedAddress);

      if (index == -1) {
        // New device - add to results
        _scanResultsValue.add(device);
        _scanResultsController.add(List.from(_scanResultsValue));
        scanStreamController.add(device);
      } else {
        // Existing device - check if it needs updating
        final existingDevice = _scanResultsValue[index];
        if (existingDevice.name != device.name ||
            existingDevice.type != device.type) {
          // Update if any important info changed
          _scanResultsValue[index] = device;
          _scanResultsController.add(List.from(_scanResultsValue));
        }
      }
    });

    _channel.invokeMethod('startScan').catchError((e) {
      print('Erro ao iniciar scan: $e');
      _stopScan();
      scanStreamController.addError(e);
    });

    Timer? timeoutTimer;
    timeoutTimer = Timer(timeout, () {
      _stopScan();
      scanStreamController.close();
    });

    // Handle stop scan
    _stopScanController.stream.first.then((_) {
      timeoutTimer?.cancel();
      scanStreamController.close();
    });

    // Cleanup when stream is cancelled
    scanStreamController.onCancel = () {
      _stopScan();
      subscription.cancel();
      timeoutTimer?.cancel();
    };

    return scanStreamController.stream;
  }

  Future<List<BluetoothDevice>> startScan(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <BluetoothDevice>[];
    await scan(timeout: timeout).forEach(devices.add);
    return devices;
  }

  /// Stops a scan for Bluetooth Low Energy devices
  Future<void> stopScan() async {
    await _channel.invokeMethod('stopScan');
    _stopScan();
  }

  void _stopScan() {
    if (_isScanningValue) {
      _isScanningValue = false;
      _isScanningController.add(_isScanningValue);
      _stopScanController.add(null);
    }
  }

  Future<dynamic> connect(BluetoothDevice device) =>
      _channel.invokeMethod('connect', device.toJson());

  Future<dynamic> disconnect() => _channel.invokeMethod('disconnect');

  Future<dynamic> destroy() => _channel.invokeMethod('destroy');

  Future<bool> printReceipt(
      {required Map<String, dynamic> config, required List<LineText> data}) {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    return _channel.invokeMethod('printReceipt', args).then((_) => true);
  }

  Future<bool> printLabel(
      {required Map<String, dynamic> config, required List<LineText> data}) {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    return _channel.invokeMethod('printLabel', args).then((_) => true);
  }

  Future<dynamic> printTest() => _channel.invokeMethod('printTest');

  void dispose() {
    _methodStreamController.close();
    _isScanningController.close();
    _scanResultsController.close();
    _stopScanController.close();
  }
}

enum BluetoothPrintStatus {
  on,
  off,
  turningOn,
  turningOff,
  connected,
  disconnected,
  unknown,
}
