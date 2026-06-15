// ignore_for_file: constant_identifier_names

/// Dispositivo Bluetooth descoberto ou emparelhado.
///
/// Identificado unicamente pelo [address] (MAC). Use o retorno de [scan] ou
/// [startScan] para obter instâncias prontas para [connect].
class BluetoothDevice {
  /// Nome exibido pelo dispositivo; pode ser `null` ou genérico.
  String? name;

  /// Endereço MAC — identificador único usado em [connect].
  String? address;

  /// Tipo do rádio Bluetooth. Use as constantes [TYPE_*].
  int? type;

  /// Indica conexão ativa no momento da descoberta (quando disponível).
  bool? connected;

  /// Tipo não identificado.
  static const int TYPE_UNKNOWN = 0;

  /// Bluetooth clássico (SPP) — comum em impressoras térmicas.
  static const int TYPE_CLASSIC = 1;

  /// Bluetooth Low Energy.
  static const int TYPE_LE = 2;

  /// Suporte dual (clássico + LE).
  static const int TYPE_DUAL = 3;

  /// Retorna [type] ou [TYPE_UNKNOWN] se nulo.
  int get effectiveType => type ?? TYPE_UNKNOWN;

  BluetoothDevice({
    this.name,
    this.address,
    this.type = 0,
  });

  /// Deserializa mapa recebido da camada nativa.
  factory BluetoothDevice.fromJson(Map<String, dynamic> json) {
    return BluetoothDevice(
      name: json['name'] as String?,
      address: json['address'] as String?,
      type: json['type'] as int? ?? 0,
    );
  }

  /// Serializa para envio à camada nativa.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (type != null) data['type'] = type;
    return data;
  }

  @override
  String toString() {
    return 'BluetoothDevice(name: $name, address: $address, type: $type)';
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is BluetoothDevice && runtimeType == other.runtimeType && address == other.address;

  @override
  int get hashCode => address.hashCode;
}
