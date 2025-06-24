import 'dart:async';
import 'package:flutter/services.dart';

/// Enumeração que representa os estados possíveis do Bluetooth
enum BluetoothPrintStatus {
  on,
  off,
  turningOn,
  turningOff,
  connected,
  disconnected,
  unknown,
}

/// Interface para leitura do estado do Bluetooth
abstract class IBluetoothState {
  Stream<BluetoothPrintStatus> get state;
}

/// Implementação que utiliza EventChannel para acompanhar mudanças no estado
class MethodChannelBluetoothState implements IBluetoothState {
  static const MethodChannel _channel =
      MethodChannel('bluetooth_print/methods');
  static const EventChannel _stateChannel =
      EventChannel('bluetooth_print/state');

  @override
  Stream<BluetoothPrintStatus> get state async* {
    final int initialState = await _channel.invokeMethod('state');
    yield _parseStatus(initialState);
    yield* _stateChannel
        .receiveBroadcastStream()
        .map((s) => _parseStatus(s as int));
  }

  BluetoothPrintStatus _parseStatus(int state) {
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
}
