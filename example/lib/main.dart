import 'dart:async';
import 'dart:developer';

import 'package:bluetooth_print/bluetooth_state.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
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
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'bluetooth_print',
        align: LineText.ALIGN_CENTER,
        width: 1,
        height: 1,
        weight: 1,
        linefeed: 1,
      ),
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Ola, teste de impressao\n',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
        weight: 1,
      ),
      LineText(
        type: LineText.TYPE_QRCODE,
        content: 'QRCODE.COM.BR',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
        weight: 1,
        size: 8,
      ),
      LineText(
        type: LineText.TYPE_BARCODE,
        content: '1234567890',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
        weight: 1,
        size: 8,
      ),
      LineText(
        type: LineText.TYPE_TEXT,
        content: '\n',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
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
              onPressed: scanDevices,
              child: Icon(Icons.search),
            );
          }
        },
      ),
    );
  }
}
