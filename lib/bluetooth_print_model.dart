/// Representa um dispositivo Bluetooth detectado ou emparelhado.
class BluetoothDevice {
  /// Nome do dispositivo (pode ser nulo).
  String? name;

  /// Endereço MAC do dispositivo (único).
  String? address;

  /// Tipo do dispositivo (ex: clássico, BLE, desconhecido).
  int? type;

  /// Se o dispositivo está atualmente conectado.
  bool? connected;

  /// Construtor padrão com valores opcionais.
  BluetoothDevice({
    this.name,
    this.address,
    this.type = 0,
    this.connected = false,
  });

  /// Cria uma instância da classe a partir de um JSON (Map).
  /// Isso é útil ao receber dados da camada nativa ou de uma API.
  factory BluetoothDevice.fromJson(Map<String, dynamic> json) {
    return BluetoothDevice(
      name: json['name'] as String?,
      address: json['address'] as String?,
      type: json['type'] as int? ?? 0,
      connected: json['connected'] as bool? ?? false,
    );
  }

  /// Converte a instância para um Map (JSON).
  /// Ideal para enviar dados para métodos nativos ou APIs.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (type != null) data['type'] = type;
    if (connected != null) data['connected'] = connected;
    return data;
  }
}

/// Representa uma linha de conteúdo para impressão.
/// Pode ser texto, imagem, código de barras ou QRCode.
class LineText {
  // Tipos suportados de impressão
  static const String TYPE_TEXT = 'text';
  static const String TYPE_BARCODE = 'barcode';
  static const String TYPE_QRCODE = 'qrcode';
  static const String TYPE_IMAGE = 'image';

  // Constantes para alinhamento de texto
  static const int ALIGN_LEFT = 0;
  static const int ALIGN_CENTER = 1;
  static const int ALIGN_RIGHT = 2;

  /// Tipo da linha (text, barcode, qrcode, image)
  final String? type;

  /// Conteúdo a ser impresso (texto ou base64 da imagem)
  final String? content;

  /// Tamanho do QR Code
  final int? size;

  /// Alinhamento do texto (0=esquerda, 1=centro, 2=direita)
  final int? align;

  /// Negrito (0=normal, 1=negrito)
  final int? weight;

  /// Largura do texto (0=normal, 1=dobrado)
  final int? width;

  /// Altura do texto (0=normal, 1=dobrado)
  final int? height;

  /// Posição absoluta do conteúdo na linha
  final int? absolutePos;

  /// Posição relativa ao conteúdo anterior
  final int? relativePos;

  /// Nível de zoom da fonte (1 a 8)
  final int? fontZoom;

  /// Sublinhado (0=não, 1=sim)
  final int? underline;

  /// Quebra de linha após a impressão (0=não, 1=sim)
  final int? linefeed;

  /// Coordenada X para impressão gráfica (imagem ou QRCode)
  final int? x;

  /// Coordenada Y para impressão gráfica
  final int? y;

  /// Construtor com valores padrão para facilitar o uso.
  LineText({
    this.type,
    this.content,
    this.size = 0,
    this.align = ALIGN_LEFT,
    this.weight = 0,
    this.width = 0,
    this.height = 0,
    this.absolutePos = 0,
    this.relativePos = 0,
    this.fontZoom = 1,
    this.underline = 0,
    this.linefeed = 0,
    this.x = 0,
    this.y = 0,
  });

  /// Cria uma instância a partir de um mapa JSON.
  factory LineText.fromJson(Map<String, dynamic> json) {
    return LineText(
      type: json['type'] as String?,
      content: json['content'] as String?,
      size: json['size'] as int?,
      align: json['align'] as int?,
      weight: json['weight'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      absolutePos: json['absolutePos'] as int?,
      relativePos: json['relativePos'] as int?,
      fontZoom: json['fontZoom'] as int?,
      underline: json['underline'] as int?,
      linefeed: json['linefeed'] as int?,
      x: json['x'] as int?,
      y: json['y'] as int?,
    );
  }

  /// Converte esta instância para JSON.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (type != null) data['type'] = type;
    if (content != null) data['content'] = content;
    if (size != null) data['size'] = size;
    if (align != null) data['align'] = align;
    if (weight != null) data['weight'] = weight;
    if (width != null) data['width'] = width;
    if (height != null) data['height'] = height;
    if (absolutePos != null) data['absolutePos'] = absolutePos;
    if (relativePos != null) data['relativePos'] = relativePos;
    if (fontZoom != null) data['fontZoom'] = fontZoom;
    if (underline != null) data['underline'] = underline;
    if (linefeed != null) data['linefeed'] = linefeed;
    if (x != null) data['x'] = x;
    if (y != null) data['y'] = y;
    return data;
  }
}
