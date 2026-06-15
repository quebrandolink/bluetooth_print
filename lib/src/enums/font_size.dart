/// Escala proporcional da fonte via comando ESC/POS `GS !` (largura e altura juntas).
///
/// Cada valor representa um multiplicador inteiro aplicado simultaneamente à
/// largura e à altura do caractere. Use [FontSize.x1] para o tamanho padrão.
///
/// > **Atenção:** quando combinado com [TextWidth.doubled] ou [TextHeight.doubled],
/// > o efeito pode se acumular — prefira usar apenas um dos dois mecanismos por elemento.
enum FontSize {
  /// 1× — tamanho padrão.
  x1,

  /// 2× largura e altura.
  x2,

  /// 3× largura e altura.
  x3,

  /// 4× largura e altura.
  x4,

  /// 5× largura e altura.
  x5,

  /// 6× largura e altura.
  x6,

  /// 7× largura e altura.
  x7,

  /// 8× largura e altura (máximo ESC/POS).
  x8;

  /// Multiplicador inteiro (1–8) enviado à camada nativa.
  int get value => index + 1;

  static FontSize fromValue(int? raw) {
    if (raw == null || raw < 1 || raw > 8) return FontSize.x1;
    return FontSize.values[raw - 1];
  }
}
