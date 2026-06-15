/// Tipo de conteúdo de uma linha de impressão.
enum LineTextType {
  /// Texto simples ou formatado (ESC/POS e TSC).
  text,

  /// Código de barras 1D — CODE128 no Android.
  barcode,

  /// QR Code.
  qrcode,

  /// Imagem raster codificada em base64.
  image,

  /// Linha de tabela com múltiplas colunas usando grade de 12 unidades.
  row;

  /// Valor string enviado à camada nativa.
  String get value => name;

  /// Rótulo legível para exibição em UI.
  String get label => switch (this) {
        LineTextType.text => 'Texto',
        LineTextType.barcode => 'Código de Barras',
        LineTextType.qrcode => 'QR Code',
        LineTextType.image => 'Imagem',
        LineTextType.row => 'Linha de Tabela',
      };

  static LineTextType fromValue(String? raw) => switch (raw) {
        'barcode' => LineTextType.barcode,
        'qrcode' => LineTextType.qrcode,
        'image' => LineTextType.image,
        'row' => LineTextType.row,
        _ => LineTextType.text,
      };
}
