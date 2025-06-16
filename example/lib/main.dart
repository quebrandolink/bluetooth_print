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
  final BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool isConnected = false;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();

    // Escaneia ao iniciar
    scanDevices();
    _listenForConnectionState();
  }

  void _listenForConnectionState() {
    bluetoothPrint.connectionState.listen((state) {
      setState(() {
        isConnected = state == BluetoothPrint.CONNECTED;
      });
    });
  }

  void scanDevices() async {
    await bluetoothPrint.disconnect();
    devices.clear();
    setState(() {
      isConnected = false;
      selectedDevice = null;
    });
    bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
    bluetoothPrint.scanResults.listen((results) {
      setState(() {
        devices = results;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    if (isConnecting) return; // Evita múltiplos cliques
    setState(() {
      isConnecting = true;
    });
    try {
      print('Conectando a ${device.name}...');
      final connected = await bluetoothPrint.connect(device);
      print('Resultado da conexão: $connected');

      if (connected) {
        setState(() {
          isConnected = true;
          selectedDevice = device;
        });
      } else {
        // Mostrar mensagem de erro
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao conectar ao dispositivo')),
          );
        }
      }
    } catch (e) {
      print('Erro ao conectar: $e');
      if (mounted) {
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
    final status = await bluetoothPrint.disconnect();
    if (status) {
      setState(() {
        isConnected = false;
        selectedDevice = null;
      });
    }
  }

  void printSample() async {
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
      /* LineText(
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
      ), */
    ];

    await bluetoothPrint.printReceipt(
      type: PrinterType.esc,
      config: config,
      data: list,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Print Example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder(
            stream: bluetoothPrint.bluetoothState,
            builder: (context, asyncSnapshot) {
              if (asyncSnapshot.hasData) {
                if (asyncSnapshot.data != BluetoothState.off) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: scanDevices,
                        child: const Text('🔍 Escanear Dispositivos'),
                      ),
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
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () => connectToDevice(device),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !isConnected ? printSample : null,
                              child: const Text('🖨️ Imprimir Teste'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: !isConnected ? disconnect : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Desconectar'),
                          ),
                        ],
                      ),
                    ],
                  );
                } else if (asyncSnapshot.data == BluetoothState.off) {
                  return const Center(child: Text('Bluetooth desligado'));
                }
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
