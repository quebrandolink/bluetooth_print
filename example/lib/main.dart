import 'dart:async';
import 'dart:developer';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: BluetoothPrintExamplePage());
  }
}

class BluetoothPrintExamplePage extends StatefulWidget {
  const BluetoothPrintExamplePage({super.key});

  @override
  State<BluetoothPrintExamplePage> createState() =>
      _BluetoothPrintExamplePageState();
}

class _BluetoothPrintExamplePageState extends State<BluetoothPrintExamplePage> {
  final BluetoothPrint bluetoothPrint = BluetoothPrint();
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool bluetoothOn = false;
  bool isConnected = false;
  bool isConnecting = false;
  StreamSubscription<BluetoothPrintStatus>? bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();

    // Liga o Bluetooth (pedindo ao usuário, se preciso) e escaneia ao iniciar
    _listenForConnectionState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ligarSePrecisoEEscanear();
    });
  }

  void _listenForConnectionState() async {
    bluetoothStateSubscription = bluetoothPrint.state.listen((state) {
      log('bluetoothPrint.bluetoothState.listen: $state');
      setState(() {
        bluetoothOn = state != BluetoothPrintStatus.off;
      });

      // O nativo filtra os eventos ACL pelo MAC da impressora, então um
      // disconnected aqui é a nossa impressora caindo (desligada, fora de
      // alcance). Sem isso o botão de imprimir continuaria habilitado.
      if (state == BluetoothPrintStatus.disconnected && isConnected) {
        _perdeuConexao('Impressora desconectada');
      }
    });
  }

  /// Zera o estado de conexão e avisa o usuário.
  void _perdeuConexao(String motivo) {
    if (!mounted) return;
    setState(() {
      isConnected = false;
      selectedDevice = null;
    });
    _mostrarMensagem(motivo);
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Traduz os códigos de erro do plugin para texto legível.
  String _mensagemDeErro(Object erro) {
    if (erro is! BluetoothPrintException) return 'Erro: $erro';
    switch (erro.code) {
      case 'not connect':
        return 'Impressora desconectada. Conecte novamente.';
      case 'printer_not_ready':
        return 'A impressora ainda não informou o tipo de comando (ESC/TSC/CPCL).';
      case 'print_failed':
        return 'Falha ao enviar os dados. A impressora continua ligada?';
      case 'connection_timeout':
        return 'A impressora não respondeu ao handshake. Ela está ligada e no alcance?';
      case 'printer_unreachable':
        return 'Impressora não encontrada. Verifique se está ligada e próxima.';
      case 'connection_lost':
        return 'A conexão caiu antes de concluir o handshake.';
      case 'bluetooth_unavailable':
        return 'Este aparelho não possui Bluetooth.';
      case 'no_permissions':
        return 'Permissão de Bluetooth negada.';
      default:
        return erro.message;
    }
  }

  /// Garante o Bluetooth ligado e então escaneia.
  ///
  /// Usado na inicialização e no botão de busca, para que "adaptador desligado"
  /// nunca vire um no-op silencioso: o usuário sempre recebe o diálogo nativo.
  Future<void> _ligarSePrecisoEEscanear() async {
    if (!await bluetoothPrint.isOn && !await enableBluetooth()) return;
    scanDevices();
  }

  /// Pede ao usuário para ligar o Bluetooth. Retorna `true` se ficou ligado.
  ///
  /// Recusar é fluxo normal: `enableBluetooth()` devolve `false` sem lançar.
  Future<bool> enableBluetooth() async {
    log('bluetoothPrint.enableBluetooth');
    try {
      if (!await bluetoothPrint.enableBluetooth()) {
        _mostrarMensagem('Bluetooth continua desligado');
        return false;
      }
    } catch (e) {
      _mostrarMensagem(_mensagemDeErro(e));
      return false;
    }

    if (!await _aguardarBluetoothLigar()) {
      _mostrarMensagem('O Bluetooth demorou para ligar. Tente novamente.');
      return false;
    }
    return true;
  }

  /// Espera o adaptador terminar de ligar.
  ///
  /// O diálogo nativo responde assim que o usuário aceita, mas o rádio ainda
  /// passa por `turningOn`. Escanear nesse intervalo não encontra nada.
  Future<bool> _aguardarBluetoothLigar({
    Duration limite = const Duration(seconds: 5),
  }) async {
    final prazo = DateTime.now().add(limite);
    while (mounted && DateTime.now().isBefore(prazo)) {
      if (await bluetoothPrint.isOn) return true;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  @override
  void dispose() {
    bluetoothStateSubscription?.cancel();
    super.dispose();
  }

  void scanDevices() async {
    log('bluetoothPrint.scanDevices');
    final isCon = await bluetoothPrint.isConnected;
    if (isCon) {
      await bluetoothPrint.disconnect();
    }
    if (await bluetoothPrint.isOn) {
      devices.clear();
      setState(() {
        isConnected = false;
        selectedDevice = null;
      });
      final listDevices = await bluetoothPrint.startScan(
        timeout: const Duration(seconds: 4),
      );
      setState(() {
        devices = listDevices;
      });
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    log('bluetoothPrint.connectToDevice');
    if (isConnecting || isConnected) return; // Evita múltiplos cliques
    setState(() {
      isConnecting = true;
      selectedDevice = device;
    });
    try {
      final connected = await bluetoothPrint.connect(device);

      if (connected) {
        setState(() {
          isConnected = true;
        });
      } else {
        // Mostrar mensagem de erro
        if (mounted) {
          setState(() {
            selectedDevice = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao conectar ao dispositivo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          selectedDevice = null;
        });
        _mostrarMensagem(_mensagemDeErro(e));
      }
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  void disconnect() async {
    log('bluetoothPrint.disconnect');
    final status = await bluetoothPrint.disconnect();
    if (status) {
      setState(() {
        isConnected = false;
        selectedDevice = null;
      });
    }
  }

  void printSample() async {
    log('bluetoothPrint.printSample');
    if (selectedDevice == null || !isConnected) return;

    final Map<String, dynamic> config = {};
    final List<LineText> list = [
      LineText.text(
        'bluetooth_print',
        styles: const LineTextStyles(
          align: TextAlign.center,
          weight: TextWeight.bold,
          width: TextWidth.doubled,
          height: TextHeight.doubled,
        ),
        linesAfter: 1,
      ),

      await LineText.imageFromAsset('assets/images/logo.png', linesAfter: 1),
      LineText.feed(),
      LineText.text(
        'Ola, teste de impressao',
        styles: LineTextStyles.centerBold,
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'TESTE DE ACENTUAÇÃO: ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃẼĨÕŨ',
        styles: LineTextStyles.centerBold,
        linesAfter: 1,
      ),
      LineText.text(
        'Teste de acentuação: áéíóúàèìòùâêîôûãẽĩõũ',
        styles: LineTextStyles.centerBold,
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Teste de caracteres especiais: ~`!@#\$\\%^&*()_+={[}]|\\:;\'",.<>/?`',
        styles: LineTextStyles.centerBold,
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Text Reverse',
        styles: const LineTextStyles(
          align: TextAlign.center,
          reverse: true,
          width: TextWidth.doubled,
          height: TextHeight.doubled,
        ),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Normal (1x1)',
        styles: const LineTextStyles(align: TextAlign.center),
        linesAfter: 1,
      ),
      LineText.text(
        'Largo (2x1) — width doubled',
        styles: const LineTextStyles(
          align: TextAlign.center,
          width: TextWidth.doubled,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Alto (1x2) — height doubled',
        styles: const LineTextStyles(
          align: TextAlign.center,
          height: TextHeight.doubled,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Grande (2x2) — width e height doubled',
        styles: const LineTextStyles(
          align: TextAlign.center,
          width: TextWidth.doubled,
          height: TextHeight.doubled,
        ),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Fonte tamanho x1 (padrão)',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x1,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte tamanho x2',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x2,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x3',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x3,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x4',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x4,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x5',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x5,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x6',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x6,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x7',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x7,
        ),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x8',
        styles: const LineTextStyles(
          align: TextAlign.center,
          fontSize: FontSize.x8,
        ),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Teste de não negrito',
        styles: LineTextStyles.center,
        linesAfter: 1,
      ),
      LineText.text(
        'Teste de negrito',
        styles: LineTextStyles.centerBold,
        linesAfter: 1,
      ),
      LineText.text(
        'Teste de sublinhado',
        styles: const LineTextStyles(
          align: TextAlign.center,
          weight: TextWeight.bold,
          underline: true,
        ),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.qrcode('QRCODE.COM.BR', size: 8, linesAfter: 1),
      LineText.barcode('1234567890', size: 8, linesAfter: 1),
      LineText.feed(),
    ];

    try {
      await bluetoothPrint.printReceipt(config: config, data: list);
      _mostrarMensagem('Impressão enviada');
    } catch (e) {
      // 'not connect' e 'print_failed' significam sessão morta: ressincroniza
      // a UI em vez de deixar o botão habilitado apontando para nada.
      if (e is BluetoothPrintException &&
          (e.code == 'not connect' || e.code == 'print_failed')) {
        _perdeuConexao(_mensagemDeErro(e));
      } else {
        _mostrarMensagem(_mensagemDeErro(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Print Example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: (!bluetoothOn)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Bluetooth desligado'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _ligarSePrecisoEEscanear(),
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Ligar Bluetooth'),
                      ),
                    ],
                  ),
                )
              : StreamBuilder(
                  stream: bluetoothPrint.isScanning,
                  builder: (context, asyncSnapshot) {
                    if (asyncSnapshot.data == true) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (_, index) {
                              final device = devices[index];
                              return ListTile(
                                title: Text(device.name ?? 'Sem nome'),
                                subtitle: Text(device.address ?? ''),
                                trailing:
                                    selectedDevice?.address == device.address
                                    ? isConnected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.green,
                                              size: 20,
                                            )
                                          : SizedBox.square(
                                              dimension: 20,
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                    : null,
                                onTap: () => connectToDevice(device),
                              );
                            },
                          ),
                        ),
                        if (isConnected)
                          Column(
                            children: [
                              const Divider(),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isConnected
                                          ? printSample
                                          : null,
                                      child: const Text('🖨️ Imprimir Teste'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: isConnected ? disconnect : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Desconectar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: bluetoothPrint.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () => bluetoothPrint.stopScan(),
              backgroundColor: Colors.red,
              child: Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
              onPressed: () => _ligarSePrecisoEEscanear(),
              child: Icon(Icons.search),
            );
          }
        },
      ),
    );
  }
}
