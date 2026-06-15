/// Altura do caractere tipográfico.
enum TextHeight {
  /// Altura padrão.
  normal,

  /// Altura dupla.
  doubled;

  /// Valor inteiro enviado à camada nativa (`0`=normal, `1`=dobrada).
  int get value => index;

  static TextHeight fromValue(int? raw) =>
      (raw != null && raw != 0) ? TextHeight.doubled : TextHeight.normal;
}
