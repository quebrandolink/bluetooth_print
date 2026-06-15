import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';

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
  State<BluetoothPrintExamplePage> createState() => _BluetoothPrintExamplePageState();
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

    // Escaneia ao iniciar
    _listenForConnectionState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scanDevices();
    });
  }

  void _listenForConnectionState() async {
    bluetoothStateSubscription = bluetoothPrint.state.listen((state) {
      log('bluetoothPrint.bluetoothState.listen: $state');
      setState(() {
        bluetoothOn = state != BluetoothPrintStatus.off;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    bluetoothStateSubscription?.cancel();
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
      final listDevices = await bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao conectar ao dispositivo')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          selectedDevice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
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
        styles: const LineTextStyles(align: TextAlign.center, weight: TextWeight.bold, width: TextWidth.doubled, height: TextHeight.doubled),
        linesAfter: 1,
      ),

      await LineText.imageFromAsset('assets/images/logo.png', linesAfter: 1),
      LineText.feed(),
      LineText.text('Ola, teste de impressao', styles: LineTextStyles.centerBold, linesAfter: 1),
      LineText.feed(),
      LineText.text('Teste de acentuação: áéíóúàèìòùâêîôûãẽĩõũ', styles: LineTextStyles.centerBold, linesAfter: 1),
      LineText.feed(),
      LineText.text('Teste de caracteres especiais: ~`!@#\$\\%^&*()_+={[}]|\\:;\'",.<>/?`', styles: LineTextStyles.centerBold, linesAfter: 1),
      LineText.feed(),
      LineText.text(
        'Text Reverse',
        styles: const LineTextStyles(align: TextAlign.center, reverse: true, width: TextWidth.doubled, height: TextHeight.doubled),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text('Normal (1x1)', styles: const LineTextStyles(align: TextAlign.center), linesAfter: 1),
      LineText.text(
        'Largo (2x1) — width doubled',
        styles: const LineTextStyles(align: TextAlign.center, width: TextWidth.doubled),
        linesAfter: 1,
      ),
      LineText.text(
        'Alto (1x2) — height doubled',
        styles: const LineTextStyles(align: TextAlign.center, height: TextHeight.doubled),
        linesAfter: 1,
      ),
      LineText.text(
        'Grande (2x2) — width e height doubled',
        styles: const LineTextStyles(align: TextAlign.center, width: TextWidth.doubled, height: TextHeight.doubled),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text(
        'Fonte tamanho x1 (padrão)',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x1),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte tamanho x2',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x2),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x3',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x3),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x4',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x4),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x5',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x5),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x6',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x6),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x7',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x7),
        linesAfter: 1,
      ),
      LineText.text(
        'Fonte x8',
        styles: const LineTextStyles(align: TextAlign.center, fontSize: FontSize.x8),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.text('Teste de não negrito', styles: LineTextStyles.center, linesAfter: 1),
      LineText.text('Teste de negrito', styles: LineTextStyles.centerBold, linesAfter: 1),
      LineText.text(
        'Teste de sublinhado',
        styles: const LineTextStyles(align: TextAlign.center, weight: TextWeight.bold, underline: true),
        linesAfter: 1,
      ),
      LineText.feed(),
      LineText.qrcode('QRCODE.COM.BR', size: 8, linesAfter: 1),
      LineText.barcode('1234567890', size: 8, linesAfter: 1),
      LineText.feed(),
    ];

    await bluetoothPrint.printReceipt(config: config, data: list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Print Example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: (!bluetoothOn)
              ? const Center(child: Text('Bluetooth desligado'))
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
                                trailing: selectedDevice?.address == device.address
                                    ? isConnected
                                          ? const Icon(Icons.check, color: Colors.green, size: 20)
                                          : SizedBox.square(dimension: 20, child: CircularProgressIndicator())
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
                                    child: ElevatedButton(onPressed: isConnected ? printSample : null, child: const Text('🖨️ Imprimir Teste')),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: isConnected ? disconnect : null,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            return FloatingActionButton(onPressed: () => bluetoothPrint.stopScan(), backgroundColor: Colors.red, child: Icon(Icons.stop));
          } else {
            return FloatingActionButton(onPressed: scanDevices, child: Icon(Icons.search));
          }
        },
      ),
    );
  }
}
