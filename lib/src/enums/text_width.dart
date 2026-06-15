/// Largura do caractere tipográfico.
enum TextWidth {
  /// Largura padrão.
  normal,

  /// Largura dupla.
  doubled;

  /// Valor inteiro enviado à camada nativa (`0`=normal, `1`=dobrada).
  int get value => index;

  static TextWidth fromValue(int? raw) =>
      (raw != null && raw != 0) ? TextWidth.doubled : TextWidth.normal;
}
