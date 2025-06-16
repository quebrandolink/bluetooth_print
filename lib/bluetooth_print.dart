import 'dart:async';
import 'package:bluetooth_print/bluetooth_print_exception.dart';
import 'package:flutter/services.dart';

import 'bluetooth_print_model.dart';
import 'bluetooth_scanner.dart';

/// Classe principal para gerenciamento de impressão Bluetooth
///
/// Fornece métodos para:
/// - Escanear dispositivos Bluetooth
/// - Gerenciar conexão com impressoras
/// - Enviar comandos de impressão
/// - Monitorar estados do Bluetooth e conexão
///
/// Deve ser descartada usando [dispose()] quando não for mais necessária
class BluetoothPrint {
  /// Namespace padrão para os canais de comunicação nativos
  static const String NAMESPACE = 'bluetooth_print';

  /// Estado constante para conexão estabelecida
  static const int CONNECTED = 1;

  /// Estado constante para desconectado
  static const int DISCONNECTED = 0;

  /// Canal para comunicação de métodos com a plataforma nativa
  static const MethodChannel _channel = MethodChannel('$NAMESPACE/methods');

  /// Canal para receber eventos de estado do Bluetooth
  static const EventChannel _stateChannel = EventChannel('$NAMESPACE/state');

  /// Controlador para stream de chamadas de método
  final StreamController<MethodCall> _methodStreamController =
      StreamController<MethodCall>.broadcast();

  /// Stream público para receber chamadas de método
  Stream<MethodCall> get methodStream => _methodStreamController.stream;

  /// Instância singleton da classe
  static final BluetoothPrint _instance = BluetoothPrint._();

  /// Getter para acessar a instância singleton
  static BluetoothPrint get instance => _instance;

  /// Instância do scanner Bluetooth interno
  final BluetoothScanner _scanner = BluetoothScanner();

  /// Flag para verificar se a instância foi descartada
  bool _isDisposed = false;

  /// Construtor privado para implementação do padrão singleton
  BluetoothPrint._() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (!_isDisposed) {
        _methodStreamController.add(call);
      }
    });
  }

  /// Libera todos os recursos utilizados pela instância
  ///
  /// Deve ser chamado quando a instância não for mais necessária
  /// para evitar vazamentos de memória
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _methodStreamController.close();
    _scanner.dispose();
  }

  /// Inicia o escaneamento de dispositivos Bluetooth
  ///
  /// [timeout]: Duração opcional para encerramento automático do escaneamento
  /// Retorna um Stream que emite dispositivos conforme são encontrados
  ///
  /// Lança [StateError] se a instância já foi descartada
  Stream<BluetoothDevice> scan({Duration? timeout}) {
    _checkIfDisposed();
    return _scanner.scan(timeout: timeout);
  }

  /// Inicia o escaneamento e retorna uma lista completa quando concluído
  ///
  /// [timeout]: Tempo máximo de escaneamento (padrão: 15 segundos)
  /// Retorna uma Future que completa com a lista de dispositivos encontrados
  ///
  /// Lança [StateError] se a instância já foi descartada
  Future<List<BluetoothDevice>> startScan(
      {Duration? timeout = const Duration(seconds: 15)}) {
    _checkIfDisposed();
    return _scanner.startScan(timeout: timeout);
  }

  /// Para o escaneamento de dispositivos manualmente
  ///
  /// Lança [StateError] se a instância já foi descartada
  Future<void> stopScan() {
    _checkIfDisposed();
    return _scanner.stopScan();
  }

  /// Stream que emite a lista atual de dispositivos encontrados
  ///
  /// Lança [StateError] se a instância já foi descartada
  Stream<List<BluetoothDevice>> get scanResults {
    _checkIfDisposed();
    return _scanner.scanResults;
  }

  /// Stream que indica se o escaneamento está ativo
  ///
  /// Lança [StateError] se a instância já foi descartada
  Stream<bool> get isScanning {
    _checkIfDisposed();
    return _scanner.isScanning;
  }

  // ========== Métodos Básicos ========== //

  /// Verifica se o Bluetooth está disponível no dispositivo
  ///
  /// Lança [StateError] se a instância já foi descartada
  Future<bool> get isAvailable {
    _checkIfDisposed();
    return _channel.invokeMethod('isAvailable').then((value) => value as bool);
  }

  /// Verifica se o Bluetooth está ativado
  ///
  /// Lança [StateError] se a instância já foi descartada
  Future<bool> get isOn {
    _checkIfDisposed();
    return _channel.invokeMethod('isOn').then((value) => value as bool);
  }

  /// Verifica o estado atual da conexão
  ///
  /// Lança [StateError] se a instância já foi descartada
  Future<bool?> get isConnected {
    _checkIfDisposed();
    return _channel.invokeMethod('isConnected');
  }

  // ========== Gerenciamento de Conexão ========== //

  /// Conecta a um dispositivo Bluetooth específico
  ///
  /// [device]: Dispositivo Bluetooth para conectar
  /// Retorna true se a conexão for bem-sucedida
  /// Lança [BluetoothPrintException] em caso de falha
  /// Lança [StateError] se a instância já foi descartada
  Future<bool> connect(BluetoothDevice device) async {
    _checkIfDisposed();
    // Verifica se já está conectado ao dispositivo
    final connected = await isConnected;
    if (connected == true) {
      final currentDevice = await _getCurrentDevice();
      if (currentDevice?.address == device.address) {
        print('Já conectado a este dispositivo');
        return true;
      }
    }
    try {
      await disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      final result =
          await _channel.invokeMethod('connect', {'address': device.address});

      if (result == true) {
        // Wait for connection state to update
        await Future.delayed(Duration(milliseconds: 1000));

        // Listen for connection state change
        final connectionCompleter = Completer<bool>();
        final sub = connectionState.listen((state) {
          if (state == CONNECTED) {
            connectionCompleter.complete(true);
          }
        });

        // Timeout after 5 seconds
        final timeout = Future.delayed(Duration(seconds: 5), () {
          connectionCompleter.complete(false);
        });

        final connected = await connectionCompleter.future;
        sub.cancel();

        if (!connected) {
          await disconnect();
        }
        return connected;
      }
      return false;
    } on PlatformException catch (e) {
      await disconnect();
      throw BluetoothPrintException(e.code, e.message ?? "Connection error");
    }
  }

  // Adicione este método para obter o dispositivo atual
  Future<BluetoothDevice?> _getCurrentDevice() async {
    try {
      final device = await _channel.invokeMethod('getCurrentDevice');
      return device != null
          ? BluetoothDevice.fromJson(Map<String, dynamic>.from(device))
          : null;
    } catch (e) {
      print('Erro ao obter dispositivo atual: $e');
      return null;
    }
  }

  /// Desconecta do dispositivo atual
  ///
  /// Retorna true se a desconexão for bem-sucedida
  /// Lança [BluetoothPrintException] em caso de falha
  /// Lança [StateError] se a instância já foi descartada
  Future<bool> disconnect() async {
    _checkIfDisposed();
    try {
      final wasConnected = await isConnected ?? false;
      if (!wasConnected) {
        return true; // Já está desconectado
      }
      return await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      throw BluetoothPrintException(e.code, e.message ?? "Erro ao desconectar");
    }
  }

  // ========== Métodos de Impressão ========== //

  /// Envia um comando de impressão para o dispositivo conectado
  ///
  /// [config]: Configurações de impressão (tamanho, alinhamento, etc.)
  /// [data]: Lista de elementos para imprimir (texto, imagens, códigos)
  /// [type]: Tipo de impressora (padrão: ESC)
  /// Retorna true se o comando for enviado com sucesso
  /// Lança [BluetoothPrintException] em caso de falha
  /// Lança [StateError] se a instância já foi descartada
  Future<bool> printReceipt({
    required Map<String, dynamic> config,
    required List<LineText> data,
    PrinterType type = PrinterType.esc,
  }) async {
    _checkIfDisposed();
    try {
      final args = {
        'type': type.index,
        'config': config,
        'data': data.map((e) => e.toJson()).toList(),
      };
      return await _channel.invokeMethod('print', args);
    } on PlatformException catch (e) {
      throw BluetoothPrintException(e.code, e.message ?? "Erro ao imprimir");
    }
  }

  // ========== Streams de Monitoramento ========== //

  /// Stream que emite mudanças no estado do Bluetooth
  ///
  /// Valores possíveis:
  /// - BluetoothState.off
  /// - BluetoothState.turningOn
  /// - BluetoothState.on
  /// - BluetoothState.turningOff
  /// - BluetoothState.unknown
  ///
  /// Lança [StateError] se a instância já foi descartada
  Stream<BluetoothState> get bluetoothState {
    _checkIfDisposed();
    return _stateChannel.receiveBroadcastStream().where((state) {
      return state is int && (state >= 10 || state <= 13 || state == -1);
    }).map((s) => _parseBluetoothState(s as int));
  }

  /// Stream que emite mudanças no estado da conexão
  ///
  /// Valores possíveis:
  /// - CONNECTED (1)
  /// - DISCONNECTED (0)
  ///
  /// Lança [StateError] se a instância já foi descartada
  Stream<int> get connectionState {
    _checkIfDisposed();
    return _connectionStateStream();
  }

  // ========== Métodos Privados ========== //

  Stream<int> _connectionStateStream() async* {
    // Emite o estado atual primeiro
    final connected = await isConnected;
    yield connected == true ? CONNECTED : DISCONNECTED;

    // Depois escuta por atualizações
    yield* methodStream
        .where((call) => call.method == "connectionState")
        .map((call) => call.arguments as int);
  }

  BluetoothState _parseBluetoothState(dynamic state) {
    switch (state) {
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

  /// Verifica se a instância foi descartada
  void _checkIfDisposed() {
    if (_isDisposed) {
      throw StateError('BluetoothPrint instance has been disposed');
    }
  }
}

/// Enum que representa os tipos de impressoras suportadas
enum PrinterType {
  /// Impressoras ESC/POS (padrão para recibos)
  esc,

  /// Impressoras TSC (etiquetas)
  tsc,

  /// Impressoras CPCL (etiquetas Zebra)
  cpcl
}

/// Enum que representa os estados possíveis do Bluetooth
enum BluetoothState {
  /// Estado desconhecido
  unknown,

  /// Bluetooth desligado
  off,

  /// Bluetooth ligando
  turningOn,

  /// Bluetooth ligado
  on,

  /// Bluetooth desligando
  turningOff
}
