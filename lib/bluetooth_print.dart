// === bluetooth_print.dart ===

// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';

import 'bluetooth_connection.dart';
import 'bluetooth_print_exception.dart';
import 'bluetooth_print_model.dart';
import 'bluetooth_printer.dart';
import 'bluetooth_scanner.dart';
import 'bluetooth_state.dart';

/// Classe unificada que encapsula todas as funcionalidades Bluetooth
/// usando as implementações baseadas nos princípios SOLID.
class BluetoothPrint {
  static const String NAMESPACE = 'bluetooth_print';
  static const MethodChannel _channel = MethodChannel('$NAMESPACE/methods');

  static final BluetoothPrint _instance = BluetoothPrint._internal();

  factory BluetoothPrint() => _instance;

  late final IBluetoothScanner _scanner;
  late final IBluetoothConnection _connection;
  late final IBluetoothPrinter _printer;
  late final IBluetoothState _state;

  BluetoothPrint._internal() {
    final methodStreamController = StreamController<MethodCall>.broadcast();

    _channel.setMethodCallHandler((call) async {
      if (!methodStreamController.isClosed) {
        methodStreamController.add(call);
      }
    });

    _scanner = MethodChannelBluetoothScanner();
    _connection = MethodChannelBluetoothConnection();
    _printer = MethodChannelBluetoothPrinter();
    _state = MethodChannelBluetoothState();
  }

  // === ESCANEAMENTO ===

  /// Inicia escaneamento de dispositivos bluetooth
  Stream<BluetoothDevice> scan(
      {Duration timeout = const Duration(seconds: 5)}) {
    try {
      return _scanner.scan(timeout: timeout);
    } catch (e) {
      throw BluetoothPrintException(
          'scan_error', 'Erro ao iniciar escaneamento: $e');
    }
  }

  /// Retorna todos os dispositivos encontrados após escaneamento
  Future<List<BluetoothDevice>> startScan(
      {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      return await _scanner.startScan(timeout: timeout);
    } catch (e) {
      throw BluetoothPrintException(
          'start_scan_error', 'Erro ao iniciar escaneamento: $e');
    }
  }

  /// Para o escaneamento de dispositivos
  Future<void> stopScan() async {
    try {
      await _scanner.stopScan();
    } catch (e) {
      throw BluetoothPrintException(
          'stop_scan_error', 'Erro ao parar escaneamento: $e');
    }
  }

  /// Stream do estado de escaneamento
  Stream<bool> get isScanning => _scanner.isScanning;

  /// Stream da lista de dispositivos encontrados
  Stream<List<BluetoothDevice>> get scanResults => _scanner.scanResults;

  // === CONEXÃO ===

  /// Conecta a um dispositivo bluetooth
  Future<bool> connect(BluetoothDevice device) async {
    try {
      return await _connection.connect(device);
    } catch (e) {
      throw BluetoothPrintException('connect_error', 'Erro ao conectar: $e');
    }
  }

  /// Desconecta o dispositivo atual
  Future<bool> disconnect() async {
    try {
      return await _connection.disconnect();
    } catch (e) {
      throw BluetoothPrintException(
          'disconnect_error', 'Erro ao desconectar: $e');
    }
  }

  /// Verifica se há dispositivo conectado
  Future<bool> get isConnected => _connection.isConnected();

  // === IMPRESSÃO ===

  /// Imprime recibo com a lista de textos e configuração
  Future<bool> printReceipt(
      {required Map<String, dynamic> config,
      required List<LineText> data}) async {
    try {
      return await _printer.printReceipt(config: config, data: data);
    } catch (e) {
      throw BluetoothPrintException(
          'print_receipt_error', 'Erro ao imprimir recibo: $e');
    }
  }

  /// Imprime etiqueta com a lista de textos e configuração
  Future<bool> printLabel(
      Map<String, dynamic> config, List<LineText> data) async {
    try {
      return await _printer.printLabel(config: config, data: data);
    } catch (e) {
      throw BluetoothPrintException(
          'print_label_error', 'Erro ao imprimir etiqueta: $e');
    }
  }

  /// Testa a impressora
  Future<dynamic> printTest() async {
    try {
      return await _printer.printTest();
    } catch (e) {
      throw BluetoothPrintException(
          'print_test_error', 'Erro no teste de impressão: $e');
    }
  }

  // === STATUS ===

  /// Stream do estado do bluetooth (on, off, conectado, etc)
  Stream<BluetoothPrintStatus> get state => _state.state;

  /// Verifica se bluetooth está disponível
  Future<bool> get isAvailable async {
    try {
      return await _channel.invokeMethod('isAvailable');
    } catch (e) {
      throw BluetoothPrintException(
          'availability_error', 'Erro ao verificar disponibilidade: $e');
    }
  }

  /// Verifica se bluetooth está ligado
  Future<bool> get isOn async {
    try {
      return await _channel.invokeMethod('isOn');
    } catch (e) {
      throw BluetoothPrintException(
          'power_error', 'Erro ao verificar se está ligado: $e');
    }
  }
}
