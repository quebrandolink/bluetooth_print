# bluetooth_print

[![pub package](https://img.shields.io/pub/v/bluetooth_print.svg)](https://pub.dartlang.org/packages/bluetooth_print)

> **English README:** [../README.md](../README.md)
> **Referência de API completa:** [API.pt-BR.md](API.pt-BR.md)

## Introdução

`bluetooth_print` é um plugin Flutter para criar apps de impressão em impressoras térmicas Bluetooth em iOS e Android. Suporta impressoras ESC/POS (modo cupom/recibo) e TSC (modo etiqueta), como os modelos Gprinter pt-280, pt-380, gp-1324 e gp-2120.

### Compatibilidade de versões

| Versão do plugin | Versão do Flutter |
| :--------------- | :---------------- |
| 4.5.0            | Flutter 3.19+     |
| 4.3.0            | Flutter 3.19+     |
| 4.0.0            | Flutter 3.x       |
| 3.0.0            | Flutter 2.x       |
| 2.0.0            | Flutter 1.12      |
| 1.2.0            | Flutter 1.9       |

## Funcionalidades

|                       | Android            | iOS                | Descrição                                               |
| :-------------------- | :----------------: | :----------------: | :------------------------------------------------------ |
| escaneamento          | :white_check_mark: | :white_check_mark: | Escaneia dispositivos Bluetooth próximos.               |
| ligar o bluetooth     | :white_check_mark: |        —           | Pede ao usuário para ligar o adaptador (diálogo nativo).|
| conexão               | :white_check_mark: | :white_check_mark: | Conecta a um dispositivo Bluetooth.                     |
| desconexão            | :white_check_mark: | :white_check_mark: | Desconecta do dispositivo atual.                        |
| estado                | :white_check_mark: | :white_check_mark: | Stream de mudanças de estado do Bluetooth.              |
| impressão de teste    | :white_check_mark: | :white_check_mark: | Imprime página de teste da impressora.                  |
| impressão de texto    | :white_check_mark: | :white_check_mark: | Imprime texto formatado com alinhamento e estilo.       |
| impressão de imagem   | :white_check_mark: | :white_check_mark: | Imprime imagem em base64.                               |
| impressão de QR code  | :white_check_mark: | :white_check_mark: | Imprime QR code com tamanho configurável.               |
| impressão de barcode  | :white_check_mark: | :white_check_mark: | Imprime código de barras com tamanho configurável.      |

## Instalação

Adicione a dependência no `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  bluetooth_print: ^4.5.1
```

## Permissões

### Android

Adicione no arquivo `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

Adicione no arquivo `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Permissão necessária para Bluetooth</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Permissão necessária para Bluetooth</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Permissão necessária para localização</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Permissão necessária para localização</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Permissão necessária para localização</string>
```

Para mais informações sobre permissões de localização no iOS, consulte a [documentação da Apple](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services).

## Como usar

Veja o [exemplo completo](../example/lib/main.dart) para um app funcional.

### Inicializar

```dart
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

final bluetoothPrint = BluetoothPrint();
```

### Escanear dispositivos

```dart
// Retorna lista de dispositivos após o timeout
final List<BluetoothDevice> devices = await bluetoothPrint.startScan(
  timeout: const Duration(seconds: 4),
);

// Ou use stream para resultados em tempo real
bluetoothPrint.scan(timeout: const Duration(seconds: 4)).listen((device) {
  print('Encontrado: ${device.name} (${device.address})');
});
```

### Ligar o bluetooth

Se o adaptador estiver desligado, `enableBluetooth()` exibe o diálogo nativo do
Android. Recusar é fluxo normal e devolve `false`, sem exceção:

```dart
if (!await bluetoothPrint.isOn) {
  if (!await bluetoothPrint.enableBluetooth()) return; // usuário recusou
}
```

⚠️ O diálogo nativo responde assim que o usuário aceita, mas o rádio ainda passa
por `turningOn`. Escanear imediatamente depois pode não encontrar nada — espere
`isOn` virar `true` (ou o estado `BluetoothPrintStatus.on` no stream) antes de
chamar `startScan()`. O `example/` traz esse encadeamento pronto.

No Windows o adaptador não pode ser ligado por código: o método apenas devolve o
estado atual, equivalente a `isOn`.

### Conectar

`connect()` só resolve depois que a impressora responde o handshake ESC/TSC/CPCL,
com um limite de 12 segundos. Um `true` aqui significa "pronta para imprimir" —
antes disso o tipo de comando é desconhecido e o job seria descartado em silêncio:

```dart
try {
  if (await bluetoothPrint.connect(device)) {
    print('Conectado com sucesso!');
  }
} on BluetoothPrintException catch (e) {
  // connection_timeout: não respondeu em 12s
  // connection_lost: o link caiu durante o handshake
  print('${e.code}: ${e.message}');
}
```

`await bluetoothPrint.isConnected` usa o mesmo critério e pode ser consultado a
qualquer momento.

### Desconectar

```dart
await bluetoothPrint.disconnect();
```

### Escutar mudanças de estado

`connected` e `disconnected` se referem à impressora conectada por `connect()` —
o nativo compara cada evento com o MAC dela, então outros dispositivos Bluetooth
(um fone, por exemplo) não mexem nesse estado. Trate `disconnected` como o sinal
para desabilitar a impressão: é o aviso mais cedo de que a impressora foi
desligada ou saiu de alcance.

```dart
bluetoothPrint.state.listen((status) {
  switch (status) {
    case BluetoothPrintStatus.connected:
      print('Impressora conectada');
      break;
    case BluetoothPrintStatus.disconnected:
      print('Impressora desconectada');
      break;
    case BluetoothPrintStatus.on:
      print('Bluetooth ligado');
      break;
    case BluetoothPrintStatus.off:
      print('Bluetooth desligado');
      break;
    default:
      break;
  }
});
```

### Imprimir cupom/recibo (modo ESC/POS)

```dart
final Map<String, dynamic> config = {};
final List<LineText> linhas = [
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'Minha Loja',
    weight: 1,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'Item à esquerda',
    align: LineText.ALIGN_LEFT,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'Item à direita',
    align: LineText.ALIGN_RIGHT,
    linefeed: 1,
  ),
  LineText(linefeed: 1),
  LineText(
    type: LineText.TYPE_BARCODE,
    content: '1234567890',
    size: 10,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_QRCODE,
    content: 'https://exemplo.com.br',
    size: 10,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
];

// Imprimir uma imagem (codificada em base64)
final ByteData data = await rootBundle.load('assets/images/logo.png');
final List<int> imageBytes =
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
final String base64Image = base64Encode(imageBytes);
linhas.add(LineText(
  type: LineText.TYPE_IMAGE,
  content: base64Image,
  align: LineText.ALIGN_CENTER,
  linefeed: 1,
));

await bluetoothPrint.printReceipt(config: config, data: linhas);
```

### Imprimir etiqueta (modo TSC)

```dart
final Map<String, dynamic> config = {
  'width': 40,   // Largura da etiqueta em mm
  'height': 70,  // Altura da etiqueta em mm
  'gap': 2,      // Espaço entre etiquetas em mm
};

// Coordenadas em DPI (1 mm = 8 DPI)
final List<LineText> linhas = [
  LineText(type: LineText.TYPE_TEXT, x: 10, y: 10, content: 'Nome do Produto'),
  LineText(type: LineText.TYPE_TEXT, x: 10, y: 40, content: 'SKU: 12345'),
  LineText(type: LineText.TYPE_QRCODE, x: 10, y: 70, content: 'https://exemplo.com.br'),
  LineText(type: LineText.TYPE_BARCODE, x: 10, y: 190, content: '1234567890'),
];

await bluetoothPrint.printLabel(config, linhas);
```

## Tratamento de Erros

Todas as operações lançam `BluetoothPrintException` em caso de falha. **Sempre
envolva as chamadas de impressão em `try/catch`**: uma impressora desligada entre
dois jobs faz o próximo falhar, e sem o `catch` isso vira uma exceção não tratada.

```dart
try {
  await bluetoothPrint.printReceipt(config: config, data: linhas);
} on BluetoothPrintException catch (e) {
  switch (e.code) {
    case 'not connect':
      // A impressora sumiu. Limpe o estado e peça nova conexão.
      break;
    case 'printer_not_ready':
      // Conectada, mas ainda não informou o tipo de comando (ESC/TSC/CPCL).
      break;
    case 'print_failed':
      // A escrita na porta falhou no meio do envio.
      break;
    default:
      print('${e.code}: ${e.message}');
  }
}
```

Os códigos mais comuns:

| Código               | Quando acontece                                             |
| :------------------- | :---------------------------------------------------------- |
| `printer_unreachable`| A porta não abriu: desligada, fora de alcance ou já em uso.   |
| `connection_timeout` | A impressora não respondeu ao handshake em 12s.              |
| `connection_lost`    | A porta abriu e o link caiu durante o handshake.             |
| `not connect`        | Imprimir sem impressora conectada (ou depois de ela cair).   |
| `printer_not_ready`  | Conectada, mas o tipo de comando ainda é desconhecido.       |
| `print_failed`       | Falha ao escrever os bytes na porta.                         |

Veja todos os códigos de erro em [API.pt-BR.md](API.pt-BR.md#códigos-de-erro).

## Resolução de Problemas

### iOS: importando bibliotecas `.a` de terceiros

Se ocorrer um erro do CocoaPods ao importar uma biblioteca `.a`, adicione ao seu `.podspec`:

```ruby
# O nome do arquivo .a deve começar com 'lib', ex: 'libXXX.a'
s.vendored_libraries = '**/*.a'
```

Veja também: [CocoaPods podspec issue no Stack Overflow](https://stackoverflow.com/questions/19189463/cocoapods-podspec-issue).

### iOS: erro de restauração de estado do CBCentralManager

Se aparecer o erro:

> `State restoration of CBCentralManager is only allowed for applications that have specified the "bluetooth-central" background mode`

Adicione ao `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Permitir uso do Bluetooth?</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Permitir uso do Bluetooth?</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

## Créditos

- Inspirado em [flutter_blue](https://github.com/pauldemarco/flutter_blue)
