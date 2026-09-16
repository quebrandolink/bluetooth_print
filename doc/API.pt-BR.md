# bluetooth_print — Referência de API (Português BR)

> **English:** [API.en.md](API.en.md)

Este documento cobre todas as classes, métodos, propriedades e enums públicos expostos pelo pacote `bluetooth_print`.

---

## Índice

- [BluetoothPrint](#bluetoothprint)
  - [Construtor](#construtor)
  - [Escaneamento](#escaneamento)
  - [Conexão](#conexão)
  - [Impressão](#impressão)
  - [Status](#status)
- [BluetoothDevice](#bluetoothdevice)
- [LineText](#linetext)
- [BluetoothPrintStatus](#bluetoothprintstatus)
- [BluetoothPrintException](#bluetoothprintexception)
- [BluetoothPrintController](#bluetoothprintcontroller)
- [Interfaces](#interfaces)

---

## BluetoothPrint

`lib/bluetooth_print.dart`

Ponto de entrada unificado para todas as operações de impressão Bluetooth. Internamente delega para `IBluetoothScanner`, `IBluetoothConnection`, `IBluetoothPrinter` e `IBluetoothState`.

### Construtor

```dart
final bluetoothPrint = BluetoothPrint();
```

`BluetoothPrint` é um singleton — toda chamada a `BluetoothPrint()` retorna a mesma instância.

---

### Escaneamento

#### `scan({Duration timeout})`

```dart
Stream<BluetoothDevice> scan({
  Duration timeout = const Duration(seconds: 5),
})
```

Retorna um `Stream` que emite cada `BluetoothDevice` recém-descoberto em tempo real. O stream se fecha automaticamente após `timeout`.

Lança `BluetoothPrintException` com código `scan_error` em caso de falha.

**Exemplo:**

```dart
bluetoothPrint.scan(timeout: const Duration(seconds: 4)).listen((device) {
  print('Encontrado: ${device.name} (${device.address})');
});
```

---

#### `startScan({Duration timeout})`

```dart
Future<List<BluetoothDevice>> startScan({
  Duration timeout = const Duration(seconds: 5),
})
```

Inicia um escaneamento e retorna todos os dispositivos encontrados como uma `List` após o término do `timeout`.

Lança `BluetoothPrintException` com código `start_scan_error` em caso de falha.

**Exemplo:**

```dart
final devices = await bluetoothPrint.startScan(
  timeout: const Duration(seconds: 4),
);
```

---

#### `stopScan()`

```dart
Future<void> stopScan()
```

Interrompe um escaneamento ativo. Seguro chamar mesmo quando nenhum escaneamento está em andamento.

Lança `BluetoothPrintException` com código `stop_scan_error` em caso de falha.

---

#### `isScanning`

```dart
Stream<bool> get isScanning
```

Stream broadcast que emite `true` quando um escaneamento começa e `false` quando termina.

---

#### `scanResults`

```dart
Stream<List<BluetoothDevice>> get scanResults
```

Stream broadcast que emite a lista atual e deduplicada de dispositivos descobertos sempre que um novo dispositivo é encontrado ou um existente é atualizado.

---

### Conexão

#### `connect(BluetoothDevice device)`

```dart
Future<bool> connect(BluetoothDevice device)
```

Conecta ao `device` e só resolve depois que a impressora responde o handshake
ESC/TSC/CPCL — não apenas quando o socket abre. Até essa resposta chegar o
dialeto de comandos é desconhecido e qualquer job de impressão seria descartado
em silêncio; esperar aqui é o que faz um `true` significar "pronta para imprimir".

O handshake tem um orçamento de **12 segundos**. A sondagem cicla
ESC → CPCL → TSC até a impressora responder ou esse prazo acabar; em caso de
falha a porta é fechada antes do erro ser reportado, sem deixar socket nem
thread de leitura pendurados.

Retorna `true` em caso de sucesso.

**Exemplo:**

```dart
try {
  if (await bluetoothPrint.connect(device)) {
    print('Conectado!');
  }
} on BluetoothPrintException catch (e) {
  print('${e.code}: ${e.message}');
}
```

**Erros:**

| Código                   | Significado                                                     |
| :----------------------- | :-------------------------------------------------------------- |
| `printer_unreachable`    | A porta nunca abriu — desligada, fora de alcance ou conectada a outro aparelho. |
| `connection_timeout`     | A impressora não respondeu ao handshake em 12s.                  |
| `connection_lost`        | A porta abriu e o link caiu antes de o handshake concluir.       |
| `connection_interrupted` | A thread de conexão foi interrompida.                            |
| `connection_error`       | Falha inesperada durante a conexão.                              |
| `connection_failed`      | Falha antes de a tentativa de conexão começar.                   |
| `invalid_argument`       | Endereço MAC ausente ou malformado.                              |
| `connect_error`          | O próprio canal de plataforma falhou.                            |

---

#### `disconnect()`

```dart
Future<bool> disconnect()
```

Desconecta do dispositivo atualmente conectado. Retorna `true` em caso de sucesso.

Lança `BluetoothPrintException` com código `disconnect_error` em caso de falha.

---

#### `isConnected`

```dart
Future<bool> get isConnected
```

Retorna `true` somente quando há impressora conectada **e** o handshake
ESC/TSC/CPCL já concluiu — a mesma condição em que
[`connect()`](#connectbluetoothdevice-device) resolve. Um socket aberto mas ainda
mudo devolve `false`, porque imprimir por ele não produziria nada.

---

### Impressão

#### `printReceipt({config, data})`

```dart
Future<bool> printReceipt({
  required Map<String, dynamic> config,
  required List<LineText> data,
})
```

Envia um job de impressão ESC/POS para a impressora conectada. `config` é um mapa de configurações opcionais (reservado para uso futuro pela maioria das impressoras). `data` é uma lista ordenada de elementos `LineText`.

Retorna `true` em caso de sucesso.

Lança `BluetoothPrintException` com código `print_receipt_error` em caso de falha.

**Exemplo:**

```dart
await bluetoothPrint.printReceipt(
  config: {},
  data: [
    LineText(
      type: LineText.TYPE_TEXT,
      content: 'Minha Loja',
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ),
    LineText(
      type: LineText.TYPE_QRCODE,
      content: 'https://exemplo.com.br',
      size: 8,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ),
  ],
);
```

---

#### `printLabel(config, data)`

```dart
Future<bool> printLabel(
  Map<String, dynamic> config,
  List<LineText> data,
)
```

Envia um job de impressão de etiqueta TSC. `config` deve conter as dimensões da etiqueta:

| Chave    | Tipo  | Unidade | Descrição                    |
| :------- | :---: | :-----: | :--------------------------- |
| `width`  | `int` | mm      | Largura da etiqueta          |
| `height` | `int` | mm      | Altura da etiqueta           |
| `gap`    | `int` | mm      | Espaço entre etiquetas       |

As coordenadas nos campos `x` e `y` de `LineText` usam DPI (**1 mm = 8 DPI**).

Retorna `true` em caso de sucesso.

Lança `BluetoothPrintException` com código `print_label_error` em caso de falha.

**Exemplo:**

```dart
await bluetoothPrint.printLabel(
  {'width': 40, 'height': 70, 'gap': 2},
  [
    LineText(type: LineText.TYPE_TEXT, x: 10, y: 10, content: 'Nome do Produto'),
    LineText(type: LineText.TYPE_BARCODE, x: 10, y: 60, content: '1234567890'),
  ],
);
```

---

#### `printTest()`

```dart
Future<dynamic> printTest()
```

Envia o comando de impressão de teste integrado à impressora.

Lança `BluetoothPrintException` com código `print_test_error` em caso de falha.

---

### Status

#### `state`

```dart
Stream<BluetoothPrintStatus> get state
```

Stream broadcast de mudanças de estado do adaptador Bluetooth e da conexão. Emite o estado atual imediatamente na primeira assinatura e a cada mudança subsequente.

`connected` e `disconnected` se referem à **impressora passada para
[`connect()`](#connectbluetoothdevice-device)**, não a dispositivos Bluetooth em
geral: o nativo compara cada evento ACL com o MAC dessa impressora, então um fone
entrando ou saindo não mexe no estado dela. `on`, `off`, `turningOn` e
`turningOff` descrevem o adaptador e não são afetados.

Um evento `disconnected` é o sinal mais cedo e mais confiável de que a impressora
sumiu — use-o para desabilitar a impressão, em vez de esperar o próximo job
falhar com `not connect`.

**Exemplo:**

```dart
bluetoothPrint.state.listen((status) {
  switch (status) {
    case BluetoothPrintStatus.connected:
      print('Impressora conectada');
    case BluetoothPrintStatus.disconnected:
      print('Impressora sumiu — desabilite a impressão');
    default:
      break;
  }
});
```

---

#### `isAvailable`

```dart
Future<bool> get isAvailable
```

Retorna `true` se o dispositivo possuir adaptador Bluetooth.

---

#### `isOn`

```dart
Future<bool> get isOn
```

Retorna `true` se o adaptador Bluetooth estiver habilitado.

---

#### `enableBluetooth()`

```dart
Future<bool> enableBluetooth()
```

Pede ao usuário para ligar o Bluetooth. No Android exibe o diálogo nativo de ativação do sistema.

Retorna `true` se o Bluetooth já estava ligado ou se o usuário aceitou, e `false` se ele recusou — recusar é fluxo normal e não gera exceção.

> **Windows:** o adaptador não pode ser ligado por código, então o método retorna o estado atual, equivalente a [`isOn`](#ison).
>
> **iOS:** não implementado — a chamada falha com `enable_bluetooth_error`. Proteja com `Platform.isAndroid || Platform.isWindows`, ou use [`isOn`](#ison) e peça ao usuário para ligar o Bluetooth nos Ajustes.

Lança `BluetoothPrintException` com código `bluetooth_unavailable` (dispositivo sem Bluetooth), `no_activity` (sem Activity em primeiro plano), `no_permissions` (BLUETOOTH_CONNECT negada) ou `already_pending` (já existe uma solicitação em andamento).

**Exemplo:**

```dart
if (!await bluetoothPrint.enableBluetooth()) {
  // Usuário recusou ligar o Bluetooth
  return;
}
final devices = await bluetoothPrint.startScan();
```

---

## BluetoothDevice

`lib/bluetooth_print_model.dart`

Representa um dispositivo Bluetooth descoberto ou emparelhado.

### Propriedades

| Propriedade | Tipo      | Descrição                                              |
| :---------- | :-------: | :----------------------------------------------------- |
| `name`      | `String?` | Nome do dispositivo (pode ser `null`).                 |
| `address`   | `String?` | Endereço MAC (identificador único).                    |
| `type`      | `int?`    | Tipo do dispositivo (ver constantes abaixo).           |
| `connected` | `bool?`   | Se o dispositivo está atualmente conectado.            |

### Constantes de Tipo

| Constante      | Valor | Descrição               |
| :------------- | :---: | :---------------------- |
| `TYPE_UNKNOWN` | `0`   | Tipo desconhecido        |
| `TYPE_CLASSIC` | `1`   | Bluetooth Clássico       |
| `TYPE_LE`      | `2`   | Bluetooth Low Energy     |
| `TYPE_DUAL`    | `3`   | Modo dual                |

### `effectiveType`

```dart
int get effectiveType
```

Retorna `type ?? TYPE_UNKNOWN`.

### Construtor

```dart
BluetoothDevice({String? name, String? address, int? type = 0})
```

### `fromJson(Map<String, dynamic> json)`

```dart
factory BluetoothDevice.fromJson(Map<String, dynamic> json)
```

Cria um `BluetoothDevice` a partir de um mapa JSON (como recebido dos canais de plataforma nativos).

### `toJson()`

```dart
Map<String, dynamic> toJson()
```

Converte esta instância para um mapa JSON (para enviar aos canais de plataforma nativos).

### Igualdade

Duas instâncias de `BluetoothDevice` são iguais se e somente se seus campos `address` são iguais.

---

## LineText

`lib/bluetooth_print_model.dart`

Representa um único elemento de impressão: texto, código de barras, QR code ou imagem.

### Constantes de Tipo

| Constante      | Valor       | Descrição                    |
| :------------- | :---------- | :--------------------------- |
| `TYPE_TEXT`    | `'text'`    | Texto simples ou formatado   |
| `TYPE_BARCODE` | `'barcode'` | Código de barras 1D          |
| `TYPE_QRCODE`  | `'qrcode'`  | QR Code                      |
| `TYPE_IMAGE`   | `'image'`   | Imagem codificada em base64  |

### Constantes de Alinhamento

| Constante      | Valor | Descrição             |
| :------------- | :---: | :-------------------- |
| `ALIGN_LEFT`   | `0`   | Alinhado à esquerda   |
| `ALIGN_CENTER` | `1`   | Centralizado          |
| `ALIGN_RIGHT`  | `2`   | Alinhado à direita    |

### Propriedades

| Propriedade   | Tipo     | Padrão | Descrição                                                   |
| :------------ | :------: | :----: | :---------------------------------------------------------- |
| `type`        | `String?`| —      | Tipo do elemento (use as constantes `TYPE_*`).              |
| `content`     | `String?`| —      | Texto a imprimir ou dados da imagem em base64.              |
| `size`        | `int?`   | `0`    | Tamanho do QR code ou código de barras (tamanho do módulo). |
| `align`       | `int?`   | `0`    | Alinhamento horizontal (use as constantes `ALIGN_*`).       |
| `weight`      | `int?`   | `0`    | Negrito: `0` = normal, `1` = negrito.                       |
| `width`       | `int?`   | `0`    | Largura: `0` = normal, `1` = dupla.                         |
| `height`      | `int?`   | `0`    | Altura: `0` = normal, `1` = dupla.                          |
| `absolutePos` | `int?`   | `0`    | Posição absoluta na linha (modo ESC).                       |
| `relativePos` | `int?`   | `0`    | Posição relativa ao elemento anterior.                      |
| `fontZoom`    | `int?`   | `1`    | Zoom da fonte (`1`–`8`).                                    |
| `underline`   | `int?`   | `0`    | Sublinhado: `0` = não, `1` = sim.                           |
| `linefeed`    | `int?`   | `0`    | Quebra de linha após o elemento: `0` = não, `1` = sim.      |
| `x`           | `int?`   | `0`    | Coordenada X em DPI para modo de etiqueta TSC.              |
| `y`           | `int?`   | `0`    | Coordenada Y em DPI para modo de etiqueta TSC.              |

### Construtor

```dart
LineText({
  String? type,
  String? content,
  int? size = 0,
  int? align = LineText.ALIGN_LEFT,
  int? weight = 0,
  int? width = 0,
  int? height = 0,
  int? absolutePos = 0,
  int? relativePos = 0,
  int? fontZoom = 1,
  int? underline = 0,
  int? linefeed = 0,
  int? x = 0,
  int? y = 0,
})
```

### `fromJson` / `toJson`

Suporta serialização de/para `Map<String, dynamic>`.

---

## BluetoothPrintStatus

`lib/bluetooth_state.dart`

Enum que representa todos os estados possíveis do adaptador Bluetooth e da conexão.

| Valor          | Descrição                                         |
| :------------- | :------------------------------------------------ |
| `on`           | Adaptador Bluetooth habilitado.                   |
| `off`          | Adaptador Bluetooth desabilitado.                 |
| `turningOn`    | Adaptador Bluetooth ligando.                      |
| `turningOff`   | Adaptador Bluetooth desligando.                   |
| `connected`    | A impressora de `connect()` está conectada.       |
| `disconnected` | Essa impressora não está mais conectada.          |
| `unknown`      | Estado não pôde ser determinado.                  |

### Mapeamento de códigos nativos → enum

| Código nativo | Valor enum      |
| :-----------: | :-------------- |
| `12`          | `on`            |
| `10`          | `off`           |
| `11`          | `turningOn`     |
| `13`          | `turningOff`    |
| `1`           | `connected`     |
| `0`           | `disconnected`  |
| outro         | `unknown`       |

---

## BluetoothPrintException

`lib/bluetooth_print_exception.dart`

Exceção personalizada lançada por todas as operações de `BluetoothPrint` em caso de erro.

```dart
class BluetoothPrintException implements Exception {
  final String code;
  final String message;
}
```

### Códigos de Erro

| Código                | Lançado por             |
| :-------------------- | :---------------------- |
| `scan_error`          | `scan()`                |
| `start_scan_error`    | `startScan()`           |
| `stop_scan_error`     | `stopScan()`            |
| `connect_error`       | `connect()`             |
| `disconnect_error`    | `disconnect()`          |
| `is_connected_error`  | `isConnected`           |
| `print_receipt_error` | `printReceipt()`        |
| `print_label_error`   | `printLabel()`          |
| `print_test_error`    | `printTest()`           |
| `availability_error`  | `isAvailable`           |
| `power_error`         | `isOn`                  |
| `printer_not_ready`   | `printReceipt()`, `printLabel()`, `printTest()` |
| `print_failed`        | `printReceipt()`, `printLabel()` |
| `not connect`         | `printReceipt()`, `printLabel()`, `printTest()` |
| `invalid_arguments`   | `printReceipt()`, `printLabel()` |
| `printer_unreachable`    | `connect()`             |
| `connection_timeout`     | `connect()`             |
| `connection_lost`        | `connect()`             |
| `connection_interrupted` | `connect()`             |
| `connection_error`       | `connect()`             |
| `connection_failed`      | `connect()`             |
| `invalid_argument`       | `connect()`             |
| `bluetooth_unavailable`  | `enableBluetooth()`     |
| `no_activity`            | `enableBluetooth()`     |
| `no_permissions`         | `enableBluetooth()`     |
| `already_pending`        | `enableBluetooth()`     |
| `enable_bluetooth_error` | `enableBluetooth()`     |

---

## BluetoothPrintController

`lib/bluetooth_print_controller.dart`

Classe coordenadora opcional que agrupa as quatro dependências de interface. Útil para injeção de dependência em testes.

```dart
final controller = BluetoothPrintController(
  scanner: MethodChannelBluetoothScanner(),
  connection: MethodChannelBluetoothConnection(),
  printer: MethodChannelBluetoothPrinter(),
  state: MethodChannelBluetoothState(),
);
```

---

## Interfaces

Essas classes abstratas definem os contratos usados por `BluetoothPrint`. Você pode implementá-las para fornecer mocks ou backends alternativos.

### `IBluetoothScanner`

```dart
abstract class IBluetoothScanner {
  Stream<BluetoothDevice> scan({Duration timeout});
  Future<List<BluetoothDevice>> startScan({Duration timeout});
  Future<void> stopScan();
  Stream<List<BluetoothDevice>> get scanResults;
  Stream<bool> get isScanning;
}
```

Implementação padrão: `MethodChannelBluetoothScanner`

---

### `IBluetoothConnection`

```dart
abstract class IBluetoothConnection {
  Future<bool> connect(BluetoothDevice device);
  Future<bool> disconnect();
  Future<bool> isConnected();
  Future<bool> destroy();
}
```

Implementação padrão: `MethodChannelBluetoothConnection`

---

### `IBluetoothPrinter`

```dart
abstract class IBluetoothPrinter {
  Future<bool> printReceipt({
    required Map<String, dynamic> config,
    required List<LineText> data,
  });
  Future<bool> printLabel({
    required Map<String, dynamic> config,
    required List<LineText> data,
  });
  Future<void> printTest();
}
```

Implementação padrão: `MethodChannelBluetoothPrinter`

---

### `IBluetoothState`

```dart
abstract class IBluetoothState {
  Stream<BluetoothPrintStatus> get state;
}
```

Implementação padrão: `MethodChannelBluetoothState`
