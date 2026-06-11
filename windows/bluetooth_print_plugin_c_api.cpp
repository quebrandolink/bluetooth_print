#include "include/bluetooth_print/bluetooth_print_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "bluetooth_print_plugin.h"

void BluetoothPrintPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  bluetooth_print::BluetoothPrintPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
