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

  @override
  void initState() {
    super.initState();

    // Escaneia ao iniciar
    scanDevices();
  }

  void scanDevices() async {
    devices.clear();
    bluetoothPrint.scanner.startScan(timeout: const Duration(seconds: 4));
    bluetoothPrint.scanner.scanResults.listen((results) {
      setState(() {
        devices = results;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    await bluetoothPrint.connect(device);
    setState(() {
      isConnected = true;
      selectedDevice = device;
    });
  }

  void disconnect() {
    bluetoothPrint.disconnect();
    setState(() {
      selectedDevice = null;
    });
  }

  void printSample() async {
    if (selectedDevice == null || !isConnected) return;

    final Map<String, dynamic> config = {};
    final List<LineText> list = [
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Olá, impressão de teste!',
        weight: 1,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Plugin bluetooth_print funcionando',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
    ];

    await bluetoothPrint.printReceipt(config, list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Print Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                    trailing: selectedDevice?.address == device.address
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
                    onPressed: isConnected ? printSample : null,
                    child: const Text('🖨️ Imprimir Teste'),
                  ),
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
      ),
    );
  }
}
