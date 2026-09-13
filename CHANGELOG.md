## 4.5.0

* android: `printReceipt`/`printLabel`/`printTest` now always answer the
  MethodChannel. The happy path queued the job on the thread pool and returned
  without calling `result.success()`, so the Dart future never completed and the
  caller stayed stuck in a "printing" state forever.
* android: `connect()` now resolves only after the ESC/TSC/CPCL handshake, not
  as soon as the socket opens. Printing in that window produced no bytes at all,
  because `getCurrentPrinterCommand()` was still `null` and no branch matched.
* android: the printer command probe starts after 300ms and retries every 800ms
  (was 1500ms/1500ms), cutting the worst case (TSC, third attempt) from ~4.5s to
  ~1.9s.
* android: a write that fails is reported as `print_failed` instead of silently
  passing — `sendDataImmediately` now returns whether the bytes reached the port.
* android: `not connect` no longer falls through and submits a second reply
  (`Reply already submitted`), and replies are posted to the main looper instead
  of through the Activity, which may already be gone when the job finishes.

## 4.4.0

* add `BluetoothPrint.enableBluetooth()`: asks the user to turn Bluetooth on
  through the native `ACTION_REQUEST_ENABLE` dialog on Android. Returns `false`
  when the user declines instead of throwing. On iOS and Windows, where the
  adapter cannot be turned on programmatically, it reports the current state.
* android: request `BLUETOOTH_CONNECT` at runtime before showing the enable
  dialog, required since Android 12.
* android: register the activity result listener as the plugin instance so it
  can be removed in `tearDown()` — the previous anonymous lambda was duplicated
  on every configuration change, replaying the pending call once per rotation.
* android: always clear the pending call/result, so a declined request no longer
  leaves state behind that a later result would replay.
* android: guard against an empty `grantResults`, which crashed with
  `ArrayIndexOutOfBoundsException` when the permission dialog was dismissed.
* `enableBluetooth()` propagates the native error code (`bluetooth_unavailable`,
  `no_activity`, `no_permissions`, `already_pending`) as
  `BluetoothPrintException.code`.

## 4.3.0

* update sdk.

## 4.2.0

* opt permission check


## 4.1.0

* Receipt print (esc mode) support set text absolute position and relative position

## 4.0.1

* support flutter 3.0.5.

## 3.0.1

* opt format.

## 3.0.0

* null safety.

## 2.0.0

* adaptation flutter 1.23.13.

## 1.2.0

* fix ios library auto import bug.

## 1.1.0

* opt ios config.


## 1.0.1

* opt log.


## 1.0.0

* support ios print label(tsc command) and receipt(esc command).

## 0.1.2

* support print label(tsc command).

## 0.1.1

* support more gprinter devices.

## 0.1.0

* finished android features.

## 0.0.5

* fixed some bugs, opt readme.

## 0.0.4

* fixed some bugs.

## 0.0.3

* opt android print, add status display.

## 0.0.2

* add android print support.

## 0.0.1

* initial release.
* TODO: Describe initial release.

