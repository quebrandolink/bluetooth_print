import 'dart:async';
import 'package:flutter/services.dart';

import 'bluetooth_print_model.dart';

/// Classe responsável por controlar a comunicação Bluetooth com impressoras.
/// Permite verificar o estado do Bluetooth, iniciar e parar escaneamento de dispositivos,
/// conectar e desconectar dispositivos, além de imprimir recibos ou etiquetas.
class BluetoothPrint {
  /// Nome do canal usado para comunicação com a parte nativa (Android/iOS).
  static const String NAMESPACE = 'bluetooth_print';

  /// Constantes que representam o estado da conexão.
  static const int CONNECTED = 1;
  static const int DISCONNECTED = 0;

  /// Canal usado para enviar comandos (métodos) para a plataforma nativa.
  static const MethodChannel _channel =
      const MethodChannel('$NAMESPACE/methods');

  /// Canal usado para receber atualizações de status do Bluetooth da plataforma nativa.
  static const EventChannel _stateChannel =
      const EventChannel('$NAMESPACE/state');

  /// Controlador interno para escutar chamadas da plataforma.
  final StreamController<MethodCall> _methodStreamController =
      StreamController.broadcast();

  /// Stream que emite eventos recebidos do canal nativo (ex: dispositivos encontrados).
  Stream<MethodCall> get _methodStream => _methodStreamController.stream;

  /// Construtor privado para configurar o listener do canal.
  BluetoothPrint._() {
    _channel.setMethodCallHandler((MethodCall call) async {
      _methodStreamController.add(call);
    });
  }

  /// Instância única (singleton) da classe.
  static final BluetoothPrint _instance = BluetoothPrint._();

  /// Acesso à instância única.
  static BluetoothPrint get instance => _instance;

  /// Verifica se o dispositivo possui Bluetooth disponível.
  Future<bool> get isAvailable async =>
      await _channel.invokeMethod('isAvailable').then<bool>((d) => d);

  /// Verifica se o Bluetooth está ligado.
  Future<bool> get isOn async =>
      await _channel.invokeMethod('isOn').then<bool>((d) => d);

  /// Verifica se há um dispositivo atualmente conectado.
  Future<bool?> get isConnected async =>
      await _channel.invokeMethod('isConnected');

  /// Controlador e stream que indicam se está ocorrendo um escaneamento de dispositivos.
  final StreamController<bool> _isScanningController =
      StreamController<bool>.broadcast();
  bool _isScanningValue = false;
  Stream<bool> get isScanning => _isScanningController.stream;

  /// Controlador e stream que contém a lista de dispositivos encontrados durante o escaneamento.
  final StreamController<List<BluetoothDevice>> _scanResultsController =
      StreamController<List<BluetoothDevice>>.broadcast();
  List<BluetoothDevice> _scanResultsValue = [];
  Stream<List<BluetoothDevice>> get scanResults =>
      _scanResultsController.stream;

  /// Controlador usado internamente para sinalizar a parada do escaneamento.
  final StreamController<void> _stopScanController =
      StreamController<void>.broadcast();

  /// Retorna o estado atual do Bluetooth e atualizações futuras (ligado, desligado, etc.).
  Stream<BluetoothPrintStatus> get state async* {
    final int stateCode = await _channel.invokeMethod('state');
    yield _getBluetoothStatus(stateCode);

    yield* _stateChannel
        .receiveBroadcastStream()
        .map((s) => _getBluetoothStatus(s as int));
  }

  /// Converte o código numérico recebido da plataforma para um estado legível.
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

  /// Inicia um escaneamento em busca de dispositivos Bluetooth por um tempo limitado.
  /// Retorna uma lista dos dispositivos encontrados em tempo real.
  Stream<BluetoothDevice> scan(
      {Duration timeout = const Duration(seconds: 5)}) {
    final scanStreamController = StreamController<BluetoothDevice>();

    if (_isScanningValue) {
      scanStreamController
          .addError(Exception('Outro escaneamento já está em andamento.'));
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

      // Normaliza o endereço do dispositivo para evitar duplicatas
      final normalizedAddress = device.address?.toUpperCase().trim();
      if (normalizedAddress == null || normalizedAddress.isEmpty) return;

      final index = _scanResultsValue.indexWhere(
          (e) => e.address?.toUpperCase().trim() == normalizedAddress);

      if (index == -1) {
        // Dispositivo novo - adicionar à lista
        _scanResultsValue.add(device);
        _scanResultsController.add(List.from(_scanResultsValue));
        scanStreamController.add(device);
      } else {
        // Dispositivo já existe - atualizar caso necessário
        final existingDevice = _scanResultsValue[index];
        if (existingDevice.name != device.name ||
            existingDevice.type != device.type) {
          _scanResultsValue[index] = device;
          _scanResultsController.add(List.from(_scanResultsValue));
        }
      }
    });

    // Inicia o escaneamento nativo
    _channel.invokeMethod('startScan').catchError((e) {
      print('Erro ao iniciar o escaneamento: $e');
      _stopScan();
      scanStreamController.addError(e);
    });

    Timer? timeoutTimer;
    timeoutTimer = Timer(timeout, () {
      _stopScan();
      scanStreamController.close();
    });

    // Finaliza quando o controle interno sinaliza parada
    _stopScanController.stream.first.then((_) {
      timeoutTimer?.cancel();
      scanStreamController.close();
    });

    // Limpeza caso o stream seja cancelado
    scanStreamController.onCancel = () {
      _stopScan();
      subscription.cancel();
      timeoutTimer?.cancel();
    };

    return scanStreamController.stream;
  }

  /// Inicia um escaneamento e retorna uma lista completa dos dispositivos encontrados após o tempo limite.
  Future<List<BluetoothDevice>> startScan(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <BluetoothDevice>[];
    await scan(timeout: timeout).forEach(devices.add);
    return devices;
  }

  /// Encerra o escaneamento atual.
  Future<void> stopScan() async {
    await _channel.invokeMethod('stopScan');
    _stopScan();
  }

  /// Função auxiliar para sinalizar o fim do escaneamento.
  void _stopScan() {
    if (_isScanningValue) {
      _isScanningValue = false;
      _isScanningController.add(_isScanningValue);
      _stopScanController.add(null);
    }
  }

  /// Conecta-se a um dispositivo Bluetooth selecionado.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      final connected = await _channel.invokeMethod('connect', device.toJson());
      return connected == true;
    } catch (e) {
      print('Erro ao conectar: $e');
      return false;
    }
  }

  /// Desconecta o dispositivo atualmente conectado.
  Future<bool> disconnect() {
    return _channel.invokeMethod('disconnect').then((_) => true);
  }

  /// Libera recursos internos usados pelo plugin Bluetooth.
  Future<bool> destroy() => _channel.invokeMethod('destroy').then((_) => true);

  /// Envia comandos para impressão de recibos.
  /// [config] contém configurações como largura, alinhamento etc.
  /// [data] é a lista de linhas de texto a serem impressas.
  Future<bool> printReceipt({
    required Map<String, dynamic> config,
    required List<LineText> data,
  }) {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    return _channel.invokeMethod('printReceipt', args).then((_) => true);
  }

  /// Envia comandos para impressão de etiquetas.
  /// Estrutura semelhante à impressão de recibo.
  Future<bool> printLabel({
    required Map<String, dynamic> config,
    required List<LineText> data,
  }) {
    final args = {
      'config': config,
      'data': data.map((m) => m.toJson()).toList(),
    };
    return _channel.invokeMethod('printLabel', args).then((_) => true);
  }

  /// Envia um comando de teste para verificar a impressora.
  Future<dynamic> printTest() => _channel.invokeMethod('printTest');

  /// Fecha todos os streams e libera os recursos usados pela instância.
  void dispose() {
    _methodStreamController.close();
    _isScanningController.close();
    _scanResultsController.close();
    _stopScanController.close();
  }
}

/// Enumeração que representa os possíveis estados do Bluetooth no dispositivo.
enum BluetoothPrintStatus {
  on, // Ligado
  off, // Desligado
  turningOn, // Ligando
  turningOff, // Desligando
  connected, // Dispositivo conectado
  disconnected, // Dispositivo desconectado
  unknown, // Estado desconhecido
}
