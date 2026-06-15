/// Estilo de fonte — normal ou negrito.
enum TextWeight {
  /// Fonte normal.
  normal,

  /// Negrito.
  bold;

  /// Valor inteiro enviado à camada nativa (`0`=normal, `1`=negrito).
  int get value => index;

  static TextWeight fromValue(int? raw) =>
      (raw != null && raw != 0) ? TextWeight.bold : TextWeight.normal;
}
