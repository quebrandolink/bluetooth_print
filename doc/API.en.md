# bluetooth_print — API Reference (English)

> **Português (PT-BR):** [API.pt-BR.md](API.pt-BR.md)

This document covers every public class, method, property, and enum exposed by the `bluetooth_print` package.

---

## Table of Contents

- [BluetoothPrint](#bluetoothprint)
  - [Constructor](#constructor)
  - [Scan](#scan)
  - [Connection](#connection)
  - [Printing](#printing)
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

Unified entry point for all Bluetooth printing operations. Internally delegates to `IBluetoothScanner`, `IBluetoothConnection`, `IBluetoothPrinter`, and `IBluetoothState`.

### Constructor

```dart
final bluetoothPrint = BluetoothPrint();
```

`BluetoothPrint` is a singleton — every call to `BluetoothPrint()` returns the same instance.

---

### Scan

#### `scan({Duration timeout})`

```dart
Stream<BluetoothDevice> scan({
  Duration timeout = const Duration(seconds: 5),
})
```

Returns a `Stream` that emits each newly discovered `BluetoothDevice` in real time. The stream closes automatically after `timeout`.

Throws `BluetoothPrintException` with code `scan_error` on failure.

**Example:**

```dart
bluetoothPrint.scan(timeout: const Duration(seconds: 4)).listen((device) {
  print('Found: ${device.name} (${device.address})');
});
```

---

#### `startScan({Duration timeout})`

```dart
Future<List<BluetoothDevice>> startScan({
  Duration timeout = const Duration(seconds: 5),
})
```

Starts a scan and returns all discovered devices as a `List` after `timeout` expires.

Throws `BluetoothPrintException` with code `start_scan_error` on failure.

**Example:**

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

Stops an active scan. Safe to call even when no scan is running.

Throws `BluetoothPrintException` with code `stop_scan_error` on failure.

---

#### `isScanning`

```dart
Stream<bool> get isScanning
```

Broadcast stream emitting `true` when a scan starts and `false` when it stops.

---

#### `scanResults`

```dart
Stream<List<BluetoothDevice>> get scanResults
```

Broadcast stream emitting the current, deduplicated list of discovered devices every time a new device is found or an existing device is updated.

---

### Connection

#### `connect(BluetoothDevice device)`

```dart
Future<bool> connect(BluetoothDevice device)
```

Attempts to connect to `device`. Returns `true` on success.

Throws `BluetoothPrintException` with code `connect_error` on failure.

**Example:**

```dart
final connected = await bluetoothPrint.connect(device);
if (connected) {
  print('Connected!');
}
```

---

#### `disconnect()`

```dart
Future<bool> disconnect()
```

Disconnects from the currently connected device. Returns `true` on success.

Throws `BluetoothPrintException` with code `disconnect_error` on failure.

---

#### `isConnected`

```dart
Future<bool> get isConnected
```

Returns `true` if a device is currently connected.

---

### Printing

#### `printReceipt({config, data})`

```dart
Future<bool> printReceipt({
  required Map<String, dynamic> config,
  required List<LineText> data,
})
```

Sends an ESC/POS print job to the connected printer. `config` is a map of optional settings (currently unused by most printers but reserved for future use). `data` is an ordered list of `LineText` items.

Returns `true` on success.

Throws `BluetoothPrintException` with code `print_receipt_error` on failure.

**Example:**

```dart
await bluetoothPrint.printReceipt(
  config: {},
  data: [
    LineText(
      type: LineText.TYPE_TEXT,
      content: 'Hello, World!',
      align: LineText.ALIGN_CENTER,
      weight: 1,
      linefeed: 1,
    ),
    LineText(
      type: LineText.TYPE_QRCODE,
      content: 'https://example.com',
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

Sends a TSC label print job. `config` must contain the label dimensions:

| Key      | Type  | Unit | Description             |
| :------- | :---: | :--: | :---------------------- |
| `width`  | `int` | mm   | Label width             |
| `height` | `int` | mm   | Label height            |
| `gap`    | `int` | mm   | Gap between labels      |

Coordinates in `LineText` (`x`, `y`) use DPI units (**1 mm = 8 DPI**).

Returns `true` on success.

Throws `BluetoothPrintException` with code `print_label_error` on failure.

**Example:**

```dart
await bluetoothPrint.printLabel(
  {'width': 40, 'height': 70, 'gap': 2},
  [
    LineText(type: LineText.TYPE_TEXT, x: 10, y: 10, content: 'Product Name'),
    LineText(type: LineText.TYPE_BARCODE, x: 10, y: 60, content: '1234567890'),
  ],
);
```

---

#### `printTest()`

```dart
Future<dynamic> printTest()
```

Sends a built-in test print command to the printer.

Throws `BluetoothPrintException` with code `print_test_error` on failure.

---

### Status

#### `state`

```dart
Stream<BluetoothPrintStatus> get state
```

Broadcast stream of Bluetooth adapter and connection state changes. Emits the current state immediately on first subscription, then emits on every state change.

**Example:**

```dart
bluetoothPrint.state.listen((status) {
  if (status == BluetoothPrintStatus.connected) {
    print('Printer connected');
  }
});
```

---

#### `isAvailable`

```dart
Future<bool> get isAvailable
```

Returns `true` if the device has a Bluetooth adapter.

---

#### `isOn`

```dart
Future<bool> get isOn
```

Returns `true` if the Bluetooth adapter is currently enabled.

---

## BluetoothDevice

`lib/bluetooth_print_model.dart`

Represents a discovered or paired Bluetooth device.

### Properties

| Property    | Type      | Description                                      |
| :---------- | :-------: | :----------------------------------------------- |
| `name`      | `String?` | Display name of the device (may be `null`).      |
| `address`   | `String?` | MAC address (unique identifier).                 |
| `type`      | `int?`    | Device type constant (see below).                |
| `connected` | `bool?`   | Whether the device is currently connected.       |

### Type Constants

| Constant       | Value | Description         |
| :------------- | :---: | :------------------ |
| `TYPE_UNKNOWN` | `0`   | Unknown type        |
| `TYPE_CLASSIC` | `1`   | Classic Bluetooth   |
| `TYPE_LE`      | `2`   | Bluetooth Low Energy |
| `TYPE_DUAL`    | `3`   | Dual-mode           |

### `effectiveType`

```dart
int get effectiveType
```

Returns `type ?? TYPE_UNKNOWN`.

### Constructor

```dart
BluetoothDevice({String? name, String? address, int? type = 0})
```

### `fromJson(Map<String, dynamic> json)`

```dart
factory BluetoothDevice.fromJson(Map<String, dynamic> json)
```

Creates a `BluetoothDevice` from a JSON map (as received from native platform channels).

### `toJson()`

```dart
Map<String, dynamic> toJson()
```

Converts this instance to a JSON map (for sending to native platform channels).

### Equality

Two `BluetoothDevice` instances are equal if and only if their `address` fields are equal.

---

## LineText

`lib/bluetooth_print_model.dart`

Represents a single print element: text, barcode, QR code, or image.

### Type Constants

| Constant       | Value       | Description           |
| :------------- | :---------- | :-------------------- |
| `TYPE_TEXT`    | `'text'`    | Plain/formatted text  |
| `TYPE_BARCODE` | `'barcode'` | 1D barcode            |
| `TYPE_QRCODE`  | `'qrcode'`  | QR code               |
| `TYPE_IMAGE`   | `'image'`   | Base64-encoded image  |

### Alignment Constants

| Constant       | Value | Description  |
| :------------- | :---: | :----------- |
| `ALIGN_LEFT`   | `0`   | Left align   |
| `ALIGN_CENTER` | `1`   | Center align |
| `ALIGN_RIGHT`  | `2`   | Right align  |

### Properties

| Property      | Type     | Default | Description                                              |
| :------------ | :------: | :-----: | :------------------------------------------------------- |
| `type`        | `String?`| —       | Element type (use the `TYPE_*` constants).               |
| `content`     | `String?`| —       | Text to print, or base64-encoded image data.             |
| `size`        | `int?`   | `0`     | Size of QR code or barcode (module size).                |
| `align`       | `int?`   | `0`     | Horizontal alignment (use `ALIGN_*` constants).          |
| `weight`      | `int?`   | `0`     | Bold: `0` = normal, `1` = bold.                         |
| `width`       | `int?`   | `0`     | Width multiplier: `0` = normal, `1` = double-wide.       |
| `height`      | `int?`   | `0`     | Height multiplier: `0` = normal, `1` = double-height.    |
| `absolutePos` | `int?`   | `0`     | Absolute horizontal position on the line (ESC mode).     |
| `relativePos` | `int?`   | `0`     | Relative horizontal position from previous element.      |
| `fontZoom`    | `int?`   | `1`     | Font zoom level (`1`–`8`).                               |
| `underline`   | `int?`   | `0`     | Underline: `0` = off, `1` = on.                          |
| `linefeed`    | `int?`   | `0`     | Line feed after element: `0` = none, `1` = yes.          |
| `x`           | `int?`   | `0`     | X coordinate in DPI for TSC label mode.                  |
| `y`           | `int?`   | `0`     | Y coordinate in DPI for TSC label mode.                  |

### Constructor

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

Supports serialization to/from `Map<String, dynamic>`.

---

## BluetoothPrintStatus

`lib/bluetooth_state.dart`

Enum representing all possible Bluetooth adapter and device states.

| Value          | Description                                |
| :------------- | :----------------------------------------- |
| `on`           | Bluetooth adapter is enabled.              |
| `off`          | Bluetooth adapter is disabled.             |
| `turningOn`    | Bluetooth adapter is turning on.           |
| `turningOff`   | Bluetooth adapter is turning off.          |
| `connected`    | A device is connected.                     |
| `disconnected` | No device is connected.                    |
| `unknown`      | State could not be determined.             |

### State codes (native → enum)

| Native code | Enum value      |
| :---------: | :-------------- |
| `12`        | `on`            |
| `10`        | `off`           |
| `11`        | `turningOn`     |
| `13`        | `turningOff`    |
| `1`         | `connected`     |
| `0`         | `disconnected`  |
| other       | `unknown`       |

---

## BluetoothPrintException

`lib/bluetooth_print_exception.dart`

Custom exception thrown by all `BluetoothPrint` operations on error.

```dart
class BluetoothPrintException implements Exception {
  final String code;
  final String message;
}
```

### Error Codes

| Code                  | Thrown by               |
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

---

## BluetoothPrintController

`lib/bluetooth_print_controller.dart`

Optional coordinator class that groups all four interface dependencies together. Useful for dependency injection in tests.

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

These abstract classes define the contracts used by `BluetoothPrint`. You can implement them to provide mocks or alternative backends.

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

Default implementation: `MethodChannelBluetoothScanner`

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

Default implementation: `MethodChannelBluetoothConnection`

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

Default implementation: `MethodChannelBluetoothPrinter`

---

### `IBluetoothState`

```dart
abstract class IBluetoothState {
  Stream<BluetoothPrintStatus> get state;
}
```

Default implementation: `MethodChannelBluetoothState`
