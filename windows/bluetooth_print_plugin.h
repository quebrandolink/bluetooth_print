#ifndef FLUTTER_PLUGIN_BLUETOOTH_PRINT_PLUGIN_H_
#define FLUTTER_PLUGIN_BLUETOOTH_PRINT_PLUGIN_H_

// Windows/Winsock headers are intentionally NOT included here.
// They are included only in bluetooth_print_plugin.cpp (as the first includes)
// to prevent the winsock.h / winsock2.h redefinition conflict that occurs
// when windows.h is pulled in transitively by Flutter headers.
// Windows-specific types are stored as uint64_t / void*.

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace bluetooth_print {

class BluetoothPrintPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit BluetoothPrintPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~BluetoothPrintPlugin();

  BluetoothPrintPlugin(const BluetoothPrintPlugin&) = delete;
  BluetoothPrintPlugin& operator=(const BluetoothPrintPlugin&) = delete;

 private:
  flutter::PluginRegistrarWindows* registrar_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;

  std::mutex event_sink_mutex_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // SOCKET (UINT_PTR on Win64) stored as uint64_t.
  // INVALID_SOCKET = ~(SOCKET)0 = 0xFFFF...FFFF
  static constexpr uint64_t kInvalidSocket = ~uint64_t{0};
  uint64_t bt_socket_ = kInvalidSocket;

  std::string connected_address_;
  std::atomic<bool> is_scanning_{false};
  std::thread scan_thread_;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Bluetooth operations
  int  GetBluetoothState();
  bool CheckIsAvailable();
  bool CheckIsOn();
  bool CheckIsConnected();
  void StartScan(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopScan();
  bool ConnectDevice(const std::string& address);
  bool DisconnectDevice();
  bool DestroyAll();
  bool SendPrintData(const flutter::EncodableMap& config,
                     const flutter::EncodableList& data);
  bool SendPrintTest();

  // Utilities (return void* / uint64_t instead of HANDLE / BTH_ADDR)
  void*    GetFirstRadio();
  uint64_t ParseBthAddr(const std::string& address);
  std::string BthAddrToString(uint64_t addr_ll);
  std::string WideToUtf8(const std::wstring& wide);
  void SendStateEvent(int state);
  std::vector<uint8_t> BuildEscReceipt(const flutter::EncodableMap& config,
                                        const flutter::EncodableList& data);
};

}  // namespace bluetooth_print

#endif  // FLUTTER_PLUGIN_BLUETOOTH_PRINT_PLUGIN_H_
