import '../enums/enums.dart';

/// Estilos de texto para [LineText.text], equivalente a `PosStyles` do esc_pos.
class LineTextStyles {
  const LineTextStyles({
    this.align = TextAlign.left,
    this.weight = TextWeight.normal,
    this.width = TextWidth.normal,
    this.height = TextHeight.normal,
    this.fontSize,
    this.underline = false,
    this.reverse = false,
  });

  /// Alinhamento horizontal.
  final TextAlign align;

  /// Peso da fonte (negrito).
  final TextWeight weight;

  /// Largura do caractere tipográfico.
  final TextWidth width;

  /// Altura do caractere tipográfico.
  final TextHeight height;

  /// Escala proporcional da fonte (`GS !`).
  final FontSize? fontSize;

  /// Sublinhado.
  final bool underline;

  /// Texto invertido (branco sobre fundo preto) — `PosStyles(reverse: true)`.
  final bool reverse;

  /// Negrito.
  static const bold = LineTextStyles(weight: TextWeight.bold);

  /// Centralizado.
  static const center = LineTextStyles(align: TextAlign.center);

  /// Centralizado e negrito.
  static const centerBold = LineTextStyles(
    align: TextAlign.center,
    weight: TextWeight.bold,
  );

  /// Texto invertido (branco sobre preto).
  static const reverseStyle = LineTextStyles(reverse: true);
}
