export '../enums/enums.dart';
export 'line_text_styles.dart';

import 'dart:convert';

import 'package:flutter/services.dart';

import '../enums/enums.dart';
import 'line_text_styles.dart';

/// Elemento de conteúdo para impressão (texto, código de barras, QR ou imagem).
///
/// Prefira os construtores nomeados ([LineText.text], [LineText.barcode],
/// [LineText.qrcode], [LineText.image], [LineText.feed]) para montar recibos.
/// Use o construtor genérico apenas para casos avançados ou [LineText.fromJson].
///
/// **Exemplo — estilo esc_pos_printer_plus:**
/// ```dart
/// LineText.text('Negrito', styles: LineTextStyles.bold, linesAfter: 1);
/// LineText.text('Sublinhado',
///     styles: const LineTextStyles(underline: true), linesAfter: 1);
/// LineText.text('Invertido',
///     styles: const LineTextStyles(reverse: true), linesAfter: 1);
/// LineText.barcode('1234567890', linesAfter: 1);
/// LineText.qrcode('https://exemplo.com.br', size: 8, linesAfter: 1);
/// LineText.feed(2);
/// ```
class LineText {
  /// Tipo do elemento.
  final LineTextType? type;

  /// Texto UTF-8 ou payload base64 (para [LineTextType.image]).
  final String? content;

  /// Tamanho do módulo do QR code (`1`–`16`; padrão nativo: `3`).
  /// Também influencia o tamanho do código de barras em algumas plataformas.
  final int? size;

  /// Alinhamento horizontal em modo recibo.
  final TextAlign align;

  /// Estilo de fonte.
  final TextWeight weight;

  /// Largura do caractere tipográfico.
  final TextWidth width;

  /// Altura do caractere tipográfico.
  final TextHeight height;

  /// Posição horizontal absoluta na linha, em pontos ESC/POS.
  final int? absolutePos;

  /// Deslocamento horizontal relativo ao elemento anterior, em pontos ESC/POS.
  final int? relativePos;

  /// Escala proporcional da fonte (`GS !`). Omita para usar o tamanho padrão da impressora.
  final FontSize? fontSize;

  /// Exibe sublinhado sob o texto.
  final bool underline;

  /// Texto invertido (branco sobre fundo preto).
  final bool reverse;

  /// Número de quebras de linha após imprimir este elemento (`0` = nenhuma).
  final int _linefeedCount;

  /// Indica se há ao menos uma quebra de linha após o elemento.
  bool get linefeed => _linefeedCount > 0;

  /// Quantidade exata de quebras de linha (útil para [LineText.feed] com contagem).
  int get linefeedCount => _linefeedCount;

  /// Coordenada X em DPI para modo etiqueta (**1 mm ≈ 8 DPI**).
  final int? x;

  /// Coordenada Y em DPI para modo etiqueta.
  final int? y;

  /// Largura em pixels para impressão de imagem raster.
  /// `null` (padrão) faz o Java usar a largura natural do bitmap.
  /// Ignorado para tipos não-imagem (texto usa [width]).
  final int? _imageWidth;

  /// Construtor genérico — prefira os construtores nomeados quando possível.
  LineText({
    this.type,
    this.content,
    this.size,
    this.align = TextAlign.left,
    this.weight = TextWeight.normal,
    this.width = TextWidth.normal,
    this.height = TextHeight.normal,
    this.absolutePos,
    this.relativePos,
    this.fontSize,
    this.underline = false,
    this.reverse = false,
    bool linefeed = false,
    int linefeedCount = 0,
    this.x,
    this.y,
    int? imageWidth,
  })  : _linefeedCount = linefeedCount > 0 ? linefeedCount : (linefeed ? 1 : 0),
        _imageWidth = imageWidth;

  /// Texto formatado (equivalente a `printer.text(...)`).
  LineText.text(
    String content, {
    LineTextStyles styles = const LineTextStyles(),
    int linesAfter = 0,
    int? absolutePos,
    int? relativePos,
  }) : this(
          type: LineTextType.text,
          content: content,
          align: styles.align,
          weight: styles.weight,
          width: styles.width,
          height: styles.height,
          fontSize: styles.fontSize,
          underline: styles.underline,
          reverse: styles.reverse,
          absolutePos: absolutePos,
          relativePos: relativePos,
          linefeedCount: linesAfter,
        );

  /// Código de barras CODE128 (equivalente a `printer.barcode(...)`).
  LineText.barcode(
    String content, {
    TextAlign align = TextAlign.center,
    int? size,
    int linesAfter = 0,
  }) : this(
          type: LineTextType.barcode,
          content: content,
          align: align,
          size: size,
          linefeedCount: linesAfter,
        );

  /// QR Code.
  LineText.qrcode(
    String content, {
    TextAlign align = TextAlign.center,
    int? size,
    int linesAfter = 0,
  }) : this(
          type: LineTextType.qrcode,
          content: content,
          align: align,
          size: size,
          linefeedCount: linesAfter,
        );

  /// Imagem raster em base64.
  ///
  /// [content] deve ser uma string base64 da imagem. Para carregar diretamente
  /// de um asset Flutter, use [LineText.imageFromAsset].
  ///
  /// [imageWidth] define a largura em pixels na impressora (`0` = usa a largura
  /// natural do bitmap). Para impressoras de 80 mm, valores típicos são 384 ou 576.
  LineText.image(
    String content, {
    TextAlign align = TextAlign.center,
    int imageWidth = 0,
    int linesAfter = 0,
  }) : this(
          type: LineTextType.image,
          content: content,
          align: align,
          imageWidth: imageWidth,
          linefeedCount: linesAfter,
        );

  /// Carrega uma imagem de um asset Flutter e a converte para base64.
  ///
  /// ```dart
  /// final img = await LineText.imageFromAsset('assets/images/logo.png', linesAfter: 1);
  /// ```
  static Future<LineText> imageFromAsset(
    String assetPath, {
    TextAlign align = TextAlign.center,
    int imageWidth = 0,
    int linesAfter = 0,
  }) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final base64 = base64Encode(bytes);
    return LineText.image(base64, align: align, imageWidth: imageWidth, linesAfter: linesAfter);
  }

  /// Texto posicionado em modo etiqueta (TSC).
  LineText.labelText(
    String content, {
    required int x,
    required int y,
  }) : this(
          type: LineTextType.text,
          content: content,
          x: x,
          y: y,
        );

  /// Insere linhas em branco no recibo (equivalente a `printer.feed(n)`).
  LineText.feed([int lines = 1]) : this(linefeedCount: lines < 1 ? 1 : lines);

  /// Deserializa um mapa recebido da camada nativa ou de storage.
  factory LineText.fromJson(Map<String, dynamic> json) {
    return LineText(
      type: LineTextType.fromValue(json['type'] as String?),
      content: json['content'] as String?,
      size: json['size'] as int?,
      align: TextAlign.fromValue(json['align'] as int?),
      weight: TextWeight.fromValue(json['weight'] as int?),
      width: TextWidth.fromValue(json['width'] as int?),
      height: TextHeight.fromValue(json['height'] as int?),
      absolutePos: json['absolutePos'] as int?,
      relativePos: json['relativePos'] as int?,
      fontSize: FontSize.fromValue(json['fontZoom'] as int?),
      underline: (json['underline'] as int? ?? 0) != 0,
      reverse: (json['reverse'] as int? ?? 0) != 0,
      linefeedCount: json['linefeed'] as int? ?? 0,
      x: json['x'] as int?,
      y: json['y'] as int?,
    );
  }

  /// Serializa para o formato esperado pela camada nativa.
  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type!.value,
      if (content != null) 'content': content,
      if (size != null) 'size': size,
      'align': align.value,
      'weight': weight.value,
      'width': _imageWidth ?? width.value,
      'height': height.value,
      if (absolutePos != null) 'absolutePos': absolutePos,
      if (relativePos != null) 'relativePos': relativePos,
      if (fontSize != null) 'fontZoom': fontSize!.value,
      'underline': underline ? 1 : 0,
      'reverse': reverse ? 1 : 0,
      'linefeed': _linefeedCount,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    };
  }
}
