/// Alinhamento horizontal do conteúdo no modo recibo (ESC/POS).
enum TextAlign {
  /// Alinhado à esquerda.
  left,

  /// Centralizado.
  center,

  /// Alinhado à direita.
  right;

  /// Valor inteiro enviado à camada nativa (`0`=esquerda, `1`=centro, `2`=direita).
  int get value => index;

  static TextAlign fromValue(int? raw) => switch (raw) {
        1 => TextAlign.center,
        2 => TextAlign.right,
        _ => TextAlign.left,
      };
}
