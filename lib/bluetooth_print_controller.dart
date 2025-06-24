import 'bluetooth_scanner.dart';
import 'bluetooth_connection.dart';
import 'bluetooth_printer.dart';
import 'bluetooth_state.dart';

/// Classe principal que coordena as operações de impressão Bluetooth.
/// Agrupa funcionalidades de escaneamento, conexão, impressão e estado.
class BluetoothPrintController {
  final IBluetoothScanner scanner;
  final IBluetoothConnection connection;
  final IBluetoothPrinter printer;
  final IBluetoothState state;

  BluetoothPrintController({
    required this.scanner,
    required this.connection,
    required this.printer,
    required this.state,
  });
}
