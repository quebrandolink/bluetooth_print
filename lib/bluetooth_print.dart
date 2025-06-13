import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

import 'bluetooth_print_model.dart';
import 'bluetooth_scanner.dart'; // Nova classe separada

class BluetoothPrint {
  static const String NAMESPACE = 'bluetooth_print';
  static const int CONNECTED = 1;
  static const int DISCONNECTED = 0;

  static const MethodChannel _channel = MethodChannel('$NAMESPACE/methods');
  static const EventChannel _stateChannel = EventChannel('$NAMESPACE/state');

  final StreamController<MethodCall> _methodStreamController =
      StreamController.broadcast();

  // Getter do stream interno para escutar retornos do canal nativo
  Stream<MethodCall> get methodStream => _methodStreamController.stream;

  static final BluetoothPrint _instance = BluetoothPrint._();
  static BluetoothPrint get instance => _instance;

  final BluetoothScanner scanner = BluetoothScanner();

  BluetoothPrint._() {
    // Esse handler escuta chamadas de métodos do código nativo para o Dart
    _channel.setMethodCallHandler((MethodCall call) async {
      _methodStreamController.add(call); // repassa pro stream
    });
  }

  Future<bool> get isAvailable async =>
      await _channel.invokeMethod('isAvailable').then<bool>((d) => d);

  Future<bool> get isOn async =>
      await _channel.invokeMethod('isOn').then<bool>((d) => d);

  Future<bool?> get isConnected async =>
      await _channel.invokeMethod('isConnected');

  // Stream com o estado do Bluetooth (ativado/desativado)
  Stream<int> get state async* {
    // Emite o estado atual imediatamente
    yield await _channel.invokeMethod('state');
    // Depois escuta mudanças contínuas via EventChannel
    yield* _stateChannel.receiveBroadcastStream().map((s) => s as int);
  }

  Future<dynamic> connect(BluetoothDevice device) =>
      _channel.invokeMethod('connect', device.toJson());

  Future<dynamic> disconnect() => _channel.invokeMethod('disconnect');

  Future<dynamic> destroy() => _channel.invokeMethod('destroy');

  Future<dynamic> printReceipt(
      Map<String, dynamic> config, List<LineText> data) {
    final args = {
      'config': config,
      'data': data.map((e) => e.toJson()).toList(),
    };
    return _channel.invokeMethod('printReceipt', args);
  }

  Future<dynamic> printLabel(Map<String, dynamic> config, List<LineText> data) {
    final args = {
      'config': config,
      'data': data.map((e) => e.toJson()).toList(),
    };
    return _channel.invokeMethod('printLabel', args);
  }

  Future<dynamic> printTest() => _channel.invokeMethod('printTest');

  Future<bool> openCashDrawer({int m = 0, int t1 = 25, int t2 = 250}) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openCashDrawer');
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('openCashDrawer', {
          'm': m,
          't1': t1,
          't2': t2,
        });
      } else {
        print('Plataforma não suportada.');
        return false;
      }
      return true;
    } on PlatformException catch (e) {
      print("Erro ao abrir gaveta: '${e.message}'.");
      return false;
    }
  }

  // StreamController para emitir os estados do Bluetooth como enum
  final StreamController<BluetoothState> _bluetoothStateController =
      StreamController<BluetoothState>.broadcast();

  /// Getter público para escutar o estado do Bluetooth em tempo real.
  /// Emite o valor atual e continua emitindo atualizações automaticamente.
  Stream<BluetoothState> get bluetoothStateStream {
    // Se for a primeira vez que está sendo escutado, inicializa
    if (!_bluetoothStateController.hasListener) {
      _initializeBluetoothStateStream();
    }
    return _bluetoothStateController.stream;
  }

// Inicializa o listener nativo do estado do Bluetooth
  void _initializeBluetoothStateStream() async {
    try {
      // Primeiro, emite o estado atual
      final int currentState = await _channel.invokeMethod('state');
      _bluetoothStateController.add(_bluetoothStateFromInt(currentState));
    } catch (e) {
      _bluetoothStateController.add(BluetoothState.unknown);
    }

    // Depois, escuta continuamente o canal nativo
    _stateChannel.receiveBroadcastStream().listen(
      (dynamic state) {
        if (state is int) {
          _bluetoothStateController.add(_bluetoothStateFromInt(state));
        }
      },
      onError: (error) {
        print('Erro ao escutar mudanças de estado do Bluetooth: $error');
      },
    );
  }

  /// Converte o valor inteiro recebido do canal nativo para o enum [BluetoothState].
  BluetoothState _bluetoothStateFromInt(int value) {
    switch (value) {
      case 10:
        return BluetoothState.off;
      case 11:
        return BluetoothState.turningOn;
      case 12:
        return BluetoothState.on;
      case 13:
        return BluetoothState.turningOff;
      default:
        return BluetoothState.unknown;
    }
  }
}

enum BluetoothState {
  unknown,
  off,
  turningOn,
  on,
  turningOff,
}
