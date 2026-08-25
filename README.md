[![pub package](https://img.shields.io/pub/v/bluetooth_print.svg)](https://pub.dartlang.org/packages/bluetooth_print)

> **Documentação em Português:** [doc/README.pt-BR.md](doc/README.pt-BR.md)
> **Full API Reference:** [doc/API.en.md](doc/API.en.md)
> **Referência de API (PT-BR):** [doc/API.pt-BR.md](doc/API.pt-BR.md)

## Introduction

BluetoothPrint is a Flutter plugin for building Bluetooth thermal printer apps on both iOS and Android. It supports ESC/POS receipt printers and TSC label printers (e.g., Gprinter pt-280, pt-380, gp-1324, gp-2120).

### Version Compatibility

| Plugin version | Flutter version |
| :------------- | :-------------- |
| 4.3.0          | Flutter 3.19+   |
| 4.0.0          | Flutter 3.x     |
| 3.0.0          | Flutter 2.x     |
| 2.0.0          | Flutter 1.12    |
| 1.2.0          | Flutter 1.9     |

## Features

|                    | Android            | iOS                | Description                                        |
| :----------------- | :----------------: | :----------------: | :------------------------------------------------- |
| scan               | :white_check_mark: | :white_check_mark: | Scan for nearby Bluetooth devices.                 |
| connect            | :white_check_mark: | :white_check_mark: | Connect to a Bluetooth device.                     |
| disconnect         | :white_check_mark: | :white_check_mark: | Disconnect from the current device.                |
| state              | :white_check_mark: | :white_check_mark: | Stream of Bluetooth state changes.                 |
| print test page    | :white_check_mark: | :white_check_mark: | Print a test page from the device.                 |
| print text         | :white_check_mark: | :white_check_mark: | Print formatted text with alignment and style.     |
| print image        | :white_check_mark: | :white_check_mark: | Print a base64-encoded image.                      |
| print QR code      | :white_check_mark: | :white_check_mark: | Print a QR code with configurable size.            |
| print barcode      | :white_check_mark: | :white_check_mark: | Print a barcode with configurable size.            |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  bluetooth_print: ^4.3.0
```

## Permissions

### Android

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

Add the following to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Need BLE permission</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Need BLE permission</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Need Location permission</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Need Location permission</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Need Location permission</string>
```

For more information about location permissions on iOS, see [Apple's documentation](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services).

## Usage

See the [full example](example/lib/main.dart) for a working app.

### Initialize

```dart
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

final bluetoothPrint = BluetoothPrint();
```

### Enable Bluetooth

```dart
// Shows the native system dialog on Android.
// Returns true if Bluetooth was already on or the user accepted,
// false if the user declined (declining does not throw).
if (!await bluetoothPrint.enableBluetooth()) {
  return;
}
```

> On iOS and Windows the adapter cannot be turned on programmatically, so
> `enableBluetooth()` just reports the current state, same as `isOn`.

### Scan for devices

```dart
// Returns a list of discovered devices after the timeout
final List<BluetoothDevice> devices = await bluetoothPrint.startScan(
  timeout: const Duration(seconds: 4),
);

// Or use a stream for real-time results
bluetoothPrint.scan(timeout: const Duration(seconds: 4)).listen((device) {
  print('Found: ${device.name} (${device.address})');
});
```

### Connect

```dart
await bluetoothPrint.connect(device);
```

### Disconnect

```dart
await bluetoothPrint.disconnect();
```

### Listen to Bluetooth state

```dart
bluetoothPrint.state.listen((status) {
  switch (status) {
    case BluetoothPrintStatus.connected:
      print('Connected');
      break;
    case BluetoothPrintStatus.disconnected:
      print('Disconnected');
      break;
    case BluetoothPrintStatus.on:
      print('Bluetooth is ON');
      break;
    case BluetoothPrintStatus.off:
      print('Bluetooth is OFF');
      break;
    default:
      break;
  }
});
```

### Print receipt (ESC/POS mode)

```dart
final Map<String, dynamic> config = {};
final List<LineText> lines = [
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'My Store',
    weight: 1,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'Item left aligned',
    align: LineText.ALIGN_LEFT,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_TEXT,
    content: 'Item right aligned',
    align: LineText.ALIGN_RIGHT,
    linefeed: 1,
  ),
  LineText(linefeed: 1),
  LineText(
    type: LineText.TYPE_BARCODE,
    content: 'A12312112',
    size: 10,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
  LineText(
    type: LineText.TYPE_QRCODE,
    content: 'https://example.com',
    size: 10,
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  ),
];

// Print an image (base64-encoded)
final ByteData data = await rootBundle.load('assets/images/logo.png');
final List<int> imageBytes =
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
final String base64Image = base64Encode(imageBytes);
lines.add(LineText(
  type: LineText.TYPE_IMAGE,
  content: base64Image,
  align: LineText.ALIGN_CENTER,
  linefeed: 1,
));

await bluetoothPrint.printReceipt(config: config, data: lines);
```

### Print label (TSC mode)

```dart
final Map<String, dynamic> config = {
  'width': 40,   // Label width in mm
  'height': 70,  // Label height in mm
  'gap': 2,      // Gap between labels in mm
};

// Coordinates are in DPI units (1 mm = 8 DPI)
final List<LineText> lines = [
  LineText(type: LineText.TYPE_TEXT, x: 10, y: 10, content: 'Product Name'),
  LineText(type: LineText.TYPE_TEXT, x: 10, y: 40, content: 'SKU: 12345'),
  LineText(type: LineText.TYPE_QRCODE, x: 10, y: 70, content: 'https://example.com'),
  LineText(type: LineText.TYPE_BARCODE, x: 10, y: 190, content: '1234567890'),
];

await bluetoothPrint.printLabel(config, lines);
```

## Troubleshooting

### iOS: importing third-party `.a` libraries

If you get a CocoaPods error when importing a `.a` library, add the following to your `.podspec`:

```ruby
# The .a filename must begin with 'lib', e.g. 'libXXX.a'
s.vendored_libraries = '**/*.a'
```

See also: [CocoaPods podspec issue on Stack Overflow](https://stackoverflow.com/questions/19189463/cocoapods-podspec-issue).

### iOS: CBCentralManager state restoration error

If you see the error:

> `State restoration of CBCentralManager is only allowed for applications that have specified the "bluetooth-central" background mode`

Add the following to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Allow App use bluetooth?</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Allow App use bluetooth?</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

## Credits

- Inspired by [flutter_blue](https://github.com/pauldemarco/flutter_blue)
