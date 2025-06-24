import 'package:bluetooth_print/bluetooth_print_exception.dart';
import 'package:flutter/services.dart';
import 'bluetooth_print_model.dart';

/// Interface para conexão Bluetooth com dispositivos
abstract class IBluetoothConnection {
  Future<bool> connect(BluetoothDevice device);
  Future<bool> disconnect();
  Future<bool> isConnected();
  Future<bool> destroy();
}

/// Implementação usando MethodChannel para gerenciar conexões Bluetooth
class MethodChannelBluetoothConnection implements IBluetoothConnection {
  static const MethodChannel _channel =
      MethodChannel('bluetooth_print/methods');

  @override
  Future<bool> connect(BluetoothDevice device) async {
    try {
      final result = await _channel.invokeMethod('connect', device.toJson());
      return result == true;
    } catch (e) {
      throw BluetoothPrintException('connect_error', 'Erro ao conectar: $e');
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
      return true;
    } catch (e) {
      throw BluetoothPrintException(
          'disconnect_error', 'Erro ao desconectar: $e');
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod('isConnected');
      return result == true;
    } catch (e) {
      throw BluetoothPrintException(
          'is_connected_error', 'Erro ao verificar conexão: $e');
    }
  }

  @override
  Future<bool> destroy() async {
    try {
      await _channel.invokeMethod('destroy');
      return true;
    } catch (e) {
      throw BluetoothPrintException(
          'destroy_error', 'Erro ao destruir conexão: $e');
    }
  }
}
