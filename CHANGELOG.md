## 4.5.1

* android: fix `connect()` always failing with `connection_timeout` since 4.5.0.
  The printer command probe was queued on the shared serial `ThreadPool`, the very
  queue `connect()` occupies while it waits for the handshake, so no ESC/TSC/CPCL
  byte was ever sent inside the 12s window and `currentPrinterCommand` stayed
  `null`. The probe now schedules itself directly on its own executor.
* android: the probe cycles ESC/CPCL/TSC until `connect()` gives up, instead of
  closing the port on its own after the third unanswered attempt (~2.7s), which
  killed printers that answer slowly. It stops as soon as the port is gone, so a
  closed port no longer throws an NPE that silently aborts the scheduled task.
* android: `connect()` reports `connection_lost` right away when the link drops
  mid-handshake, instead of spinning out the full 12s and blaming a timeout, and
  closes the port before reporting either failure so no socket or `PrinterReader`
  thread is left behind.
* android: tapping a printer that is switched off now fails with the new
  `printer_unreachable` code instead of `connection_lost` — the RFCOMM socket
  never opened, so nothing was lost. That address is also dropped from the
  session's device map, so it stops being re-emitted by every later scan.
* android: `isConnected` answered `threadPool != null`, which is `true` forever
  after the first connection attempt and never looked at a printer at all. It now
  reports whether the current printer finished the handshake, the same criterion
  `connect()` uses.
* android: the `connected`/`disconnected` events on the state stream were emitted
  for every Bluetooth device, so unrelated hardware (a headset, say) moved the
  printer's state. `ACL_CONNECTED`/`ACL_DISCONNECTED` are now matched against the
  connected printer's MAC, which is what `BluetoothPrintStatus` already documented.
* example: handle a printer that goes away. The app now clears its connection
  state on `disconnected`, catches errors from `printReceipt` (a second print
  after powering the printer off threw an unhandled `not connect` exception) and
  turns each error code into a readable message. When the adapter is off it now
  asks to turn it on — on startup and from the search button, not just from a
  separate button — and waits for the radio to actually reach the on state before
  scanning, since the native dialog answers while it is still turning on.
* test: cover `connect()` and the print methods, including that the native error
  codes (`connection_lost`, `connection_timeout`, `not connect`,
  `printer_not_ready`, `print_failed`) reach the caller as `BluetoothPrintException`.

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

