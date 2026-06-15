import 'package:bluetooth_print/src/bluetooth_print_exception.dart';
import 'package:flutter/services.dart';
import 'models/line_text.dart';

/// Interface para impressão via Bluetooth
abstract class IBluetoothPrinter {
  Future<bool> printReceipt({
    required Map<String, dynamic> config,
    required List<LineText> data,
  });

  Future<bool> printLabel({
    required Map<String, dynamic> config,
    required List<LineText> data,
  });

  Future<void> printTest();
}

/// Implementação usando MethodChannel para enviar comandos de impressão
class MethodChannelBluetoothPrinter implements IBluetoothPrinter {
  static const MethodChannel _channel = MethodChannel('bluetooth_print/methods');

  @override
  Future<bool> printReceipt({
    required Map<String, dynamic> config,
    required List<LineText> data,
  }) async {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    try {
      await _channel.invokeMethod('printReceipt', args);
    } catch (e) {
      throw BluetoothPrintException('print_receipt_error', 'Erro ao imprimir recibo: $e');
    }
    return true;
  }

  @override
  Future<bool> printLabel({
    required Map<String, dynamic> config,
    required List<LineText> data,
  }) async {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    try {
      await _channel.invokeMethod('printLabel', args);
    } catch (e) {
      throw BluetoothPrintException('print_label_error', 'Erro ao imprimir etiqueta: $e');
    }
    return true;
  }

  @override
  Future<void> printTest() async {
    try {
      await _channel.invokeMethod('printTest');
    } catch (e) {
      throw BluetoothPrintException('print_test_error', 'Erro no teste de impressão: $e');
    }
  }
}
