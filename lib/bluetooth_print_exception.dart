/// Exceção específica para erros na impressão Bluetooth
class BluetoothPrintException implements Exception {
  /// Código do erro
  final String code;

  /// Mensagem descritiva do erro
  final String message;

  /// Cria uma nova exceção com código e mensagem
  BluetoothPrintException(this.code, this.message);

  @override
  String toString() => 'BluetoothPrintException($code): $message';
}
