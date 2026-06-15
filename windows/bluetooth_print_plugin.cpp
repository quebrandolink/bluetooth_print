// winsock2.h MUST be included before any other Windows headers.
// _WINSOCKAPI_ prevents windows.h (pulled in by Flutter headers) from
// including the old winsock.h v1, which would cause type-redefinition errors.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef _WINSOCKAPI_
#define _WINSOCKAPI_
#endif
#include <winsock2.h>
#include <windows.h>
#include <ws2bth.h>
#include <BluetoothAPIs.h>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "Bthprops.lib")

#include "bluetooth_print_plugin.h"

#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace bluetooth_print {

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

void BluetoothPrintPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  WSADATA wsa_data;
  WSAStartup(MAKEWORD(2, 2), &wsa_data);

  auto plugin = std::make_unique<BluetoothPrintPlugin>(registrar);
  auto* plugin_ptr = plugin.get();

  // Method channel: bluetooth_print/methods
  plugin->method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "bluetooth_print/methods",
          &flutter::StandardMethodCodec::GetInstance());

  plugin->method_channel_->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  // Event channel: bluetooth_print/state
  plugin->event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "bluetooth_print/state",
          &flutter::StandardMethodCodec::GetInstance());

  auto stream_handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_ptr](const flutter::EncodableValue*,
                       std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(plugin_ptr->event_sink_mutex_);
            plugin_ptr->event_sink_ = std::move(events);
            return nullptr;
          },
          [plugin_ptr](const flutter::EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(plugin_ptr->event_sink_mutex_);
            plugin_ptr->event_sink_.reset();
            return nullptr;
          });

  plugin->event_channel_->SetStreamHandler(std::move(stream_handler));

  registrar->AddPlugin(std::move(plugin));
}

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------

BluetoothPrintPlugin::BluetoothPrintPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

BluetoothPrintPlugin::~BluetoothPrintPlugin() {
  is_scanning_ = false;
  if (scan_thread_.joinable()) {
    scan_thread_.join();
  }
  if (bt_socket_ != kInvalidSocket) {
    closesocket(static_cast<SOCKET>(bt_socket_));
    bt_socket_ = kInvalidSocket;
  }
  WSACleanup();
}

// ---------------------------------------------------------------------------
// Method call dispatcher
// ---------------------------------------------------------------------------

void BluetoothPrintPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "state") {
    result->Success(flutter::EncodableValue(GetBluetoothState()));
  } else if (method == "isAvailable") {
    result->Success(flutter::EncodableValue(CheckIsAvailable()));
  } else if (method == "isOn") {
    result->Success(flutter::EncodableValue(CheckIsOn()));
  } else if (method == "isConnected") {
    result->Success(flutter::EncodableValue(CheckIsConnected()));

  } else if (method == "startScan") {
    StartScan(std::move(result));

  } else if (method == "stopScan") {
    StopScan();
    result->Success(flutter::EncodableValue());

  } else if (method == "connect") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("invalid_argument", "Expected map"); return; }
    auto it = args->find(flutter::EncodableValue("address"));
    if (it == args->end()) { result->Error("invalid_argument", "Missing 'address'"); return; }
    const auto* addr_str = std::get_if<std::string>(&it->second);
    if (!addr_str) { result->Error("invalid_argument", "'address' must be a string"); return; }
    result->Success(flutter::EncodableValue(ConnectDevice(*addr_str)));

  } else if (method == "disconnect") {
    result->Success(flutter::EncodableValue(DisconnectDevice()));

  } else if (method == "destroy") {
    result->Success(flutter::EncodableValue(DestroyAll()));

  } else if (method == "print" || method == "printReceipt" || method == "printLabel") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("invalid_argument", "Expected map"); return; }
    auto cfg_it  = args->find(flutter::EncodableValue("config"));
    auto data_it = args->find(flutter::EncodableValue("data"));
    if (cfg_it == args->end() || data_it == args->end()) {
      result->Error("invalid_argument", "Missing 'config' or 'data'");
      return;
    }
    const auto* config = std::get_if<flutter::EncodableMap>(&cfg_it->second);
    const auto* data   = std::get_if<flutter::EncodableList>(&data_it->second);
    if (!config || !data) { result->Error("invalid_argument", "Wrong types"); return; }
    result->Success(flutter::EncodableValue(SendPrintData(*config, *data)));

  } else if (method == "printTest") {
    result->Success(flutter::EncodableValue(SendPrintTest()));

  } else {
    result->NotImplemented();
  }
}

// ---------------------------------------------------------------------------
// Bluetooth state helpers
// ---------------------------------------------------------------------------

// Returns HANDLE as void*; caller is responsible for CloseHandle.
void* BluetoothPrintPlugin::GetFirstRadio() {
  BLUETOOTH_FIND_RADIO_PARAMS rp = {sizeof(BLUETOOTH_FIND_RADIO_PARAMS)};
  HANDLE hRadio = nullptr;
  HBLUETOOTH_RADIO_FIND hFind = BluetoothFindFirstRadio(&rp, &hRadio);
  if (hFind) BluetoothFindRadioClose(hFind);
  return static_cast<void*>(hRadio);
}

int BluetoothPrintPlugin::GetBluetoothState() {
  HANDLE hRadio = static_cast<HANDLE>(GetFirstRadio());
  if (!hRadio) return 10;  // STATE_OFF / unavailable
  CloseHandle(hRadio);
  return 12;  // STATE_ON
}

bool BluetoothPrintPlugin::CheckIsAvailable() {
  HANDLE hRadio = static_cast<HANDLE>(GetFirstRadio());
  if (!hRadio) return false;
  CloseHandle(hRadio);
  return true;
}

bool BluetoothPrintPlugin::CheckIsOn() {
  return GetBluetoothState() == 12;
}

bool BluetoothPrintPlugin::CheckIsConnected() {
  return bt_socket_ != kInvalidSocket;
}

// ---------------------------------------------------------------------------
// Scan
// ---------------------------------------------------------------------------

void BluetoothPrintPlugin::StartScan(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (is_scanning_) {
    result->Success(flutter::EncodableValue());
    return;
  }

  // Respond to Dart immediately; scan happens in background
  result->Success(flutter::EncodableValue());

  is_scanning_ = true;
  if (scan_thread_.joinable()) scan_thread_.join();

  scan_thread_ = std::thread([this]() {
    HANDLE hRadio = static_cast<HANDLE>(GetFirstRadio());

    auto report = [this](const BLUETOOTH_DEVICE_INFO& info) {
      std::string addr = BthAddrToString(info.Address.ullLong);
      std::string name = WideToUtf8(info.szName);
      flutter::EncodableMap m;
      m[flutter::EncodableValue("address")] = flutter::EncodableValue(addr);
      m[flutter::EncodableValue("name")]    = flutter::EncodableValue(name);
      m[flutter::EncodableValue("type")]    = flutter::EncodableValue(1);
      // InvokeMethod is thread-safe on Flutter Windows desktop
      method_channel_->InvokeMethod(
          "ScanResult",
          std::make_unique<flutter::EncodableValue>(std::move(m)));
    };

    // Phase 1: already-paired devices (returns immediately)
    {
      BLUETOOTH_DEVICE_SEARCH_PARAMS p = {sizeof(p)};
      p.fReturnAuthenticated = TRUE;
      p.fReturnRemembered    = TRUE;
      p.fReturnUnknown       = FALSE;
      p.fReturnConnected     = TRUE;
      p.fIssueInquiry        = FALSE;
      p.cTimeoutMultiplier   = 0;
      p.hRadio               = hRadio;

      BLUETOOTH_DEVICE_INFO info = {sizeof(info)};
      HBLUETOOTH_DEVICE_FIND hFind = BluetoothFindFirstDevice(&p, &info);
      if (hFind) {
        do {
          if (!is_scanning_) break;
          if (wcslen(info.szName) > 0) report(info);
        } while (BluetoothFindNextDevice(hFind, &info));
        BluetoothFindDeviceClose(hFind);
      }
    }

    // Phase 2: active inquiry for undiscovered devices (~8 sec)
    if (is_scanning_) {
      BLUETOOTH_DEVICE_SEARCH_PARAMS p = {sizeof(p)};
      p.fReturnAuthenticated = TRUE;
      p.fReturnRemembered    = TRUE;
      p.fReturnUnknown       = TRUE;
      p.fReturnConnected     = TRUE;
      p.fIssueInquiry        = TRUE;
      p.cTimeoutMultiplier   = 6;   // 6 * 1.28s ≈ 7.7s
      p.hRadio               = hRadio;

      BLUETOOTH_DEVICE_INFO info = {sizeof(info)};
      HBLUETOOTH_DEVICE_FIND hFind = BluetoothFindFirstDevice(&p, &info);
      if (hFind) {
        do {
          if (!is_scanning_) break;
          if (wcslen(info.szName) > 0) report(info);
        } while (BluetoothFindNextDevice(hFind, &info));
        BluetoothFindDeviceClose(hFind);
      }
    }

    if (hRadio) CloseHandle(hRadio);
    is_scanning_ = false;
  });
}

void BluetoothPrintPlugin::StopScan() {
  is_scanning_ = false;
  // Don't join here to avoid blocking the UI thread during the inquiry
}

// ---------------------------------------------------------------------------
// Connection
// ---------------------------------------------------------------------------

// "AA:BB:CC:DD:EE:FF" → BTH_ADDR (ULONGLONG = uint64_t)
uint64_t BluetoothPrintPlugin::ParseBthAddr(const std::string& address) {
  BLUETOOTH_ADDRESS bt = {};
  unsigned int b[6] = {};
  if (sscanf_s(address.c_str(), "%02X:%02X:%02X:%02X:%02X:%02X",
               &b[0], &b[1], &b[2], &b[3], &b[4], &b[5]) == 6) {
    bt.rgBytes[5] = static_cast<BYTE>(b[0]);
    bt.rgBytes[4] = static_cast<BYTE>(b[1]);
    bt.rgBytes[3] = static_cast<BYTE>(b[2]);
    bt.rgBytes[2] = static_cast<BYTE>(b[3]);
    bt.rgBytes[1] = static_cast<BYTE>(b[4]);
    bt.rgBytes[0] = static_cast<BYTE>(b[5]);
  }
  return bt.ullLong;
}

std::string BluetoothPrintPlugin::BthAddrToString(uint64_t addr_ll) {
  BLUETOOTH_ADDRESS bt = {};
  bt.ullLong = addr_ll;
  char buf[18];
  snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
           bt.rgBytes[5], bt.rgBytes[4], bt.rgBytes[3],
           bt.rgBytes[2], bt.rgBytes[1], bt.rgBytes[0]);
  return std::string(buf);
}

std::string BluetoothPrintPlugin::WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int sz = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1,
                               nullptr, 0, nullptr, nullptr);
  if (sz <= 0) return {};
  std::string out(sz - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1,
                      &out[0], sz, nullptr, nullptr);
  return out;
}

bool BluetoothPrintPlugin::ConnectDevice(const std::string& address) {
  DisconnectDevice();

  SOCKET sock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
  if (sock == INVALID_SOCKET) return false;

  SOCKADDR_BTH sa = {};
  sa.addressFamily  = AF_BTH;
  sa.btAddr         = static_cast<BTH_ADDR>(ParseBthAddr(address));
  sa.serviceClassId = SerialPortServiceClass_UUID;
  sa.port           = BT_PORT_ANY;

  if (connect(sock, reinterpret_cast<SOCKADDR*>(&sa), sizeof(sa)) == SOCKET_ERROR) {
    closesocket(sock);
    return false;
  }

  bt_socket_         = static_cast<uint64_t>(sock);
  connected_address_ = address;
  SendStateEvent(1);  // connected
  return true;
}

bool BluetoothPrintPlugin::DisconnectDevice() {
  if (bt_socket_ == kInvalidSocket) return true;
  closesocket(static_cast<SOCKET>(bt_socket_));
  bt_socket_ = kInvalidSocket;
  connected_address_.clear();
  SendStateEvent(0);  // disconnected
  return true;
}

bool BluetoothPrintPlugin::DestroyAll() {
  StopScan();
  DisconnectDevice();
  return true;
}

// ---------------------------------------------------------------------------
// State events
// ---------------------------------------------------------------------------

void BluetoothPrintPlugin::SendStateEvent(int state) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  if (event_sink_) {
    event_sink_->Success(flutter::EncodableValue(state));
  }
}

// ---------------------------------------------------------------------------
// Printing (ESC/POS)
// ---------------------------------------------------------------------------

namespace {

// Converte UTF-8 para Windows-1252 (CP1252). Caracteres sem mapeamento viram '?'.
static std::vector<uint8_t> Utf8ToWindows1252(const std::string& utf8) {
  // Mapeamento dos bytes 0x80-0x9F (exclusivos do CP1252 vs ISO-8859-1)
  static const uint32_t kCp1252Extra[32] = {
    0x20AC, 0,      0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0,      0x017D, 0,
    0,      0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0,      0x017E, 0x0178
  };

  std::vector<uint8_t> out;
  size_t i = 0;
  while (i < utf8.size()) {
    uint32_t cp = 0;
    uint8_t c = static_cast<uint8_t>(utf8[i]);
    if (c < 0x80) {
      cp = c; i += 1;
    } else if ((c & 0xE0) == 0xC0 && i + 1 < utf8.size()) {
      cp = ((c & 0x1F) << 6) | (static_cast<uint8_t>(utf8[i+1]) & 0x3F); i += 2;
    } else if ((c & 0xF0) == 0xE0 && i + 2 < utf8.size()) {
      cp = ((c & 0x0F) << 12) | ((static_cast<uint8_t>(utf8[i+1]) & 0x3F) << 6)
                               |  (static_cast<uint8_t>(utf8[i+2]) & 0x3F); i += 3;
    } else if ((c & 0xF8) == 0xF0 && i + 3 < utf8.size()) {
      cp = ((c & 0x07) << 18) | ((static_cast<uint8_t>(utf8[i+1]) & 0x3F) << 12)
                               | ((static_cast<uint8_t>(utf8[i+2]) & 0x3F) << 6)
                               |  (static_cast<uint8_t>(utf8[i+3]) & 0x3F); i += 4;
    } else {
      out.push_back('?'); i++; continue;
    }

    if (cp < 0x80) {
      out.push_back(static_cast<uint8_t>(cp));
    } else if (cp >= 0xA0 && cp <= 0xFF) {
      out.push_back(static_cast<uint8_t>(cp));
    } else {
      bool found = false;
      for (int j = 0; j < 32; j++) {
        if (kCp1252Extra[j] == cp) {
          out.push_back(static_cast<uint8_t>(0x80 + j));
          found = true;
          break;
        }
      }
      if (!found) out.push_back('?');
    }
  }
  return out;
}

}  // namespace

std::vector<uint8_t> BluetoothPrintPlugin::BuildEscReceipt(
    const flutter::EncodableMap& config,
    const flutter::EncodableList& data) {
  std::vector<uint8_t> buf;

  // Initialize printer
  buf.insert(buf.end(), {0x1B, 0x40});
  // Seleciona codepage WPC1252 (Windows-1252) — suporte a acentos portugueses e travessão
  buf.insert(buf.end(), {0x1B, 0x74, 0x10});

  for (const auto& item_val : data) {
    const auto* item = std::get_if<flutter::EncodableMap>(&item_val);
    if (!item) continue;

    auto get_int = [&](const std::string& key, int def = 0) -> int {
      auto it = item->find(flutter::EncodableValue(key));
      if (it == item->end()) return def;
      if (const auto* v = std::get_if<int>(&it->second)) return *v;
      return def;
    };
    auto get_str = [&](const std::string& key) -> std::string {
      auto it = item->find(flutter::EncodableValue(key));
      if (it == item->end()) return {};
      if (const auto* v = std::get_if<std::string>(&it->second)) return *v;
      return {};
    };

    int align     = get_int("align");       // 0=left, 1=center, 2=right
    int bold      = get_int("bold");
    int font_size = get_int("fontSize");
    std::string content = get_str("content");

    // Alignment
    buf.insert(buf.end(), {0x1B, 0x61, static_cast<uint8_t>(align & 0x03)});

    // Bold
    buf.insert(buf.end(), {0x1B, 0x45, static_cast<uint8_t>(bold > 0 ? 1 : 0)});

    // Font size (double height + width for size >= 2)
    uint8_t esc_size = (font_size >= 2) ? 0x11 : 0x00;
    buf.insert(buf.end(), {0x1D, 0x21, esc_size});

    // Texto codificado em Windows-1252 para compatibilidade com o codepage da impressora
    auto encoded = Utf8ToWindows1252(content);
    buf.insert(buf.end(), encoded.begin(), encoded.end());
    buf.push_back(0x0A);  // newline
  }

  // Reset formatting
  buf.insert(buf.end(), {0x1D, 0x21, 0x00});
  buf.insert(buf.end(), {0x1B, 0x45, 0x00});

  // Feed 3 lines then partial cut
  buf.insert(buf.end(), {0x1B, 0x64, 0x03});
  buf.insert(buf.end(), {0x1D, 0x56, 0x42, 0x00});

  return buf;
}

bool BluetoothPrintPlugin::SendPrintData(
    const flutter::EncodableMap& config,
    const flutter::EncodableList& data) {
  if (bt_socket_ == kInvalidSocket) return false;

  std::vector<uint8_t> bytes = BuildEscReceipt(config, data);
  if (bytes.empty()) return false;

  SOCKET sock = static_cast<SOCKET>(bt_socket_);
  const char* ptr = reinterpret_cast<const char*>(bytes.data());
  int remaining   = static_cast<int>(bytes.size());
  while (remaining > 0) {
    int sent = send(sock, ptr, remaining, 0);
    if (sent == SOCKET_ERROR) return false;
    ptr += sent;
    remaining -= sent;
  }
  return true;
}

bool BluetoothPrintPlugin::SendPrintTest() {
  if (bt_socket_ == kInvalidSocket) return false;

  const uint8_t test[] = {
    0x1B, 0x40,                          // ESC @ — init
    0x1B, 0x61, 0x01,                    // center align
    'T', 'E', 'S', 'T', 0x0A,
    0x1B, 0x64, 0x03,                    // feed 3 lines
    0x1D, 0x56, 0x42, 0x00              // cut
  };

  SOCKET sock = static_cast<SOCKET>(bt_socket_);
  int sent = send(sock, reinterpret_cast<const char*>(test), sizeof(test), 0);
  return sent != SOCKET_ERROR;
}

}  // namespace bluetooth_print
