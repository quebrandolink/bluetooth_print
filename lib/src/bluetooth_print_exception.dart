/// Erro retornado pelas operações de [BluetoothPrint].
///
/// [code] identifica a operação que falhou (ex.: `connect_error`,
/// `print_receipt_error`). [message] traz detalhes legíveis, incluindo
/// a causa original quando disponível.
class BluetoothPrintException implements Exception {
  /// Identificador estável do tipo de erro.
  final String code;

  /// Descrição do erro em português.
  final String message;

  BluetoothPrintException(this.code, this.message);

  @override
  String toString() => 'BluetoothPrintException($code): $message';
}
