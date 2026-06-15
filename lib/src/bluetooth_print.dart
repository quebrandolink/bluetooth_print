// === bluetooth_print.dart ===

// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/services.dart';

import 'bluetooth_connection.dart';
import 'bluetooth_print_exception.dart';
import 'models/bluetooth_device.dart';
import 'models/line_text.dart';
import 'bluetooth_printer.dart';
import 'bluetooth_scanner.dart';
import 'bluetooth_state.dart';

/// Ponto de entrada para impressão via Bluetooth.
///
/// Singleton — toda chamada a [BluetoothPrint] retorna a mesma instância.
/// Delega escaneamento, conexão, impressão e status para implementações
/// internas via MethodChannel.
///
/// **Fluxo típico:**
/// ```dart
/// final bt = BluetoothPrint();
/// if (!await bt.isOn) return;
///
/// final devices = await bt.startScan(timeout: const Duration(seconds: 4));
/// final printer = devices.first;
///
/// if (await bt.connect(printer)) {
///   await bt.printReceipt(config: {}, data: [LineText(content: 'Olá')]);
/// }
/// ```
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

  /// Descobre dispositivos Bluetooth emitindo cada um em tempo real.
  ///
  /// [timeout] define quanto tempo o escaneamento permanece ativo antes de
  /// encerrar o stream automaticamente.
  ///
  /// Para obter a lista completa de uma vez, prefira [startScan].
  /// Para acompanhar o progresso, use [isScanning] e [scanResults].
  ///
  /// **Exemplo:**
  /// ```dart
  /// bt.scan(timeout: const Duration(seconds: 4)).listen((device) {
  ///   print('${device.name} — ${device.address}');
  /// });
  /// ```
  ///
  /// Lança [BluetoothPrintException] com código `scan_error` em falha.
  Stream<BluetoothDevice> scan({Duration timeout = const Duration(seconds: 5)}) {
    try {
      return _scanner.scan(timeout: timeout);
    } catch (e) {
      throw BluetoothPrintException('scan_error', 'Erro ao iniciar escaneamento: $e');
    }
  }

  /// Escaneia e retorna todos os dispositivos encontrados após [timeout].
  ///
  /// A lista é deduplicada por endereço MAC. Dispositivos já emparelhados
  /// e recém-descobertos podem aparecer juntos.
  ///
  /// **Exemplo:**
  /// ```dart
  /// final devices = await bt.startScan(timeout: const Duration(seconds: 4));
  /// final printer = devices.firstWhere((d) => d.name?.contains('Printer') ?? false);
  /// ```
  ///
  /// Lança [BluetoothPrintException] com código `start_scan_error` em falha.
  Future<List<BluetoothDevice>> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      return await _scanner.startScan(timeout: timeout);
    } catch (e) {
      throw BluetoothPrintException('start_scan_error', 'Erro ao iniciar escaneamento: $e');
    }
  }

  /// Interrompe um escaneamento em andamento.
  ///
  /// Seguro chamar mesmo quando nenhum escaneamento está ativo.
  ///
  /// Lança [BluetoothPrintException] com código `stop_scan_error` em falha.
  Future<void> stopScan() async {
    try {
      await _scanner.stopScan();
    } catch (e) {
      throw BluetoothPrintException('stop_scan_error', 'Erro ao parar escaneamento: $e');
    }
  }

  /// Emite `true` enquanto um escaneamento está ativo e `false` ao terminar.
  Stream<bool> get isScanning => _scanner.isScanning;

  /// Emite a lista acumulada de dispositivos sempre que um novo é descoberto.
  ///
  /// Útil para atualizar a UI reativamente durante [scan] ou [startScan].
  Stream<List<BluetoothDevice>> get scanResults => _scanner.scanResults;

  // === CONEXÃO ===

  /// Conecta à impressora [device].
  ///
  /// Retorna `true` se a conexão foi estabelecida. É necessário estar
  /// conectado antes de chamar [printReceipt], [printLabel] ou [printTest].
  ///
  /// **Exemplo:**
  /// ```dart
  /// if (await bt.connect(device)) {
  ///   // pronto para imprimir
  /// }
  /// ```
  ///
  /// Lança [BluetoothPrintException] com código `connect_error` em falha.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      return await _connection.connect(device);
    } catch (e) {
      throw BluetoothPrintException('connect_error', 'Erro ao conectar: $e');
    }
  }

  /// Desconecta da impressora atualmente conectada.
  ///
  /// Retorna `true` em caso de sucesso.
  ///
  /// Lança [BluetoothPrintException] com código `disconnect_error` em falha.
  Future<bool> disconnect() async {
    try {
      return await _connection.disconnect();
    } catch (e) {
      throw BluetoothPrintException('disconnect_error', 'Erro ao desconectar: $e');
    }
  }

  /// Indica se há uma impressora conectada no momento.
  Future<bool> get isConnected => _connection.isConnected();

  // === IMPRESSÃO ===

  /// Imprime um recibo ESC/POS na impressora conectada.
  ///
  /// [data] é a lista ordenada de elementos a imprimir. Cada [LineText] define
  /// o conteúdo e a formatação da linha (tipo, alinhamento, negrito, etc.).
  ///
  /// [config] é um mapa de configurações **globais** do job de impressão.
  /// Atualmente nenhuma chave é consumida pelas implementações nativas (Android
  /// e Windows); o parâmetro existe para compatibilidade com a API e uso futuro.
  /// Passe um mapa vazio `{}` — é o caso mais comum.
  ///
  /// A formatação por linha (texto, QR code, código de barras, imagem) fica em
  /// [data], não em [config]. Veja [LineText] para os campos disponíveis.
  ///
  /// **Exemplos de [config]:**
  ///
  /// Recibo padrão (recomendado):
  /// ```dart
  /// final config = <String, dynamic>{};
  /// ```
  ///
  /// Placeholder para extensões futuras (ignorado hoje, mas válido na API):
  /// ```dart
  /// final config = <String, dynamic>{
  ///   // Reservado: cortar papel, avanço de linhas, codepage, etc.
  /// };
  /// ```
  ///
  /// **Exemplo completo:**
  /// ```dart
  /// await printReceipt(
  ///   config: {},
  ///   data: [
  ///     LineText(
  ///       type: LineTextType.text,
  ///       content: 'Minha Loja',
  ///       align: TextAlign.center,
  ///       weight: TextWeight.bold,
  ///       width: TextWidth.doubled,
  ///       height: TextHeight.doubled,
  ///       linefeed: true,
  ///     ),
  ///     LineText(
  ///       type: LineTextType.qrcode,
  ///       content: 'https://exemplo.com.br',
  ///       size: 8,
  ///       align: TextAlign.center,
  ///       linefeed: true,
  ///     ),
  ///   ],
  /// );
  /// ```
  ///
  /// Para impressão de **etiquetas** TSC (dimensões em mm), use [printLabel],
  /// cujo [config] aceita `width`, `height` e `gap`.
  ///
  /// Retorna `true` em caso de sucesso.
  ///
  /// Lança [BluetoothPrintException] com código `print_receipt_error` em falha.
  Future<bool> printReceipt({required Map<String, dynamic> config, required List<LineText> data}) async {
    try {
      return await _printer.printReceipt(config: config, data: data);
    } catch (e) {
      throw BluetoothPrintException('print_receipt_error', 'Erro ao imprimir recibo: $e');
    }
  }

  /// Imprime uma etiqueta no modo TSC/TSPL.
  ///
  /// Requer impressora de etiquetas compatível. Diferente de [printReceipt],
  /// aqui [config] define as dimensões físicas da etiqueta e [data] usa
  /// coordenadas [LineText.x] e [LineText.y] em vez de alinhamento.
  ///
  /// **Chaves de [config]:**
  ///
  /// | Chave    | Tipo  | Unidade | Descrição              |
  /// |----------|-------|---------|------------------------|
  /// | `width`  | `int` | mm      | Largura da etiqueta    |
  /// | `height` | `int` | mm      | Altura da etiqueta     |
  /// | `gap`    | `int` | mm      | Espaço entre etiquetas |
  ///
  /// Coordenadas em [data]: **1 mm ≈ 8 DPI** (ex.: `x: 80` ≈ 10 mm).
  ///
  /// **Exemplo:**
  /// ```dart
  /// await bt.printLabel(
  ///   {'width': 40, 'height': 70, 'gap': 2},
  ///   [
  ///     LineText(type: LineTextType.text, x: 10, y: 10, content: 'Produto'),
  ///     LineText(type: LineTextType.barcode, x: 10, y: 60, content: '1234567890'),
  ///   ],
  /// );
  /// ```
  ///
  /// Retorna `true` em caso de sucesso.
  ///
  /// Lança [BluetoothPrintException] com código `print_label_error` em falha.
  Future<bool> printLabel(Map<String, dynamic> config, List<LineText> data) async {
    try {
      return await _printer.printLabel(config: config, data: data);
    } catch (e) {
      throw BluetoothPrintException('print_label_error', 'Erro ao imprimir etiqueta: $e');
    }
  }

  /// Envia página de teste integrada à impressora conectada.
  ///
  /// Útil para validar conexão e funcionamento básico sem montar [LineText].
  ///
  /// Lança [BluetoothPrintException] com código `print_test_error` em falha.
  Future<dynamic> printTest() async {
    try {
      return await _printer.printTest();
    } catch (e) {
      throw BluetoothPrintException('print_test_error', 'Erro no teste de impressão: $e');
    }
  }

  // === STATUS ===

  /// Acompanha mudanças de estado do adaptador e da conexão.
  ///
  /// Emite o estado atual na primeira assinatura e a cada mudança posterior.
  /// Valores possíveis: [BluetoothPrintStatus.on], [BluetoothPrintStatus.off],
  /// [BluetoothPrintStatus.connected], [BluetoothPrintStatus.disconnected], etc.
  ///
  /// **Exemplo:**
  /// ```dart
  /// bt.state.listen((status) {
  ///   if (status == BluetoothPrintStatus.connected) {
  ///     // impressora pronta
  ///   }
  /// });
  /// ```
  Stream<BluetoothPrintStatus> get state => _state.state;

  /// Indica se o dispositivo possui adaptador Bluetooth.
  ///
  /// Lança [BluetoothPrintException] com código `availability_error` em falha.
  Future<bool> get isAvailable async {
    try {
      return await _channel.invokeMethod('isAvailable');
    } catch (e) {
      throw BluetoothPrintException('availability_error', 'Erro ao verificar disponibilidade: $e');
    }
  }

  /// Indica se o adaptador Bluetooth está ligado.
  ///
  /// Lança [BluetoothPrintException] com código `power_error` em falha.
  Future<bool> get isOn async {
    try {
      return await _channel.invokeMethod('isOn');
    } catch (e) {
      throw BluetoothPrintException('power_error', 'Erro ao verificar se está ligado: $e');
    }
  }
}
