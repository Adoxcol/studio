#include "studio_tray.h"

#include <shellapi.h>

#include <cstring>

#include <flutter/standard_method_codec.h>

#include "resource.h"
#include "studio_instance.h"

namespace {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring wide(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

}  // namespace

StudioTray::StudioTray(flutter::BinaryMessenger* messenger, HWND hwnd)
    : hwnd_(hwnd) {
  nid_.cbSize = sizeof(NOTIFYICONDATA);
  nid_.hWnd = hwnd_;
  nid_.uID = 1;
  nid_.uCallbackMessage = kCallback;
  nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "studio/tray", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  // Explicit VKs — hotkey_manager has no Windows keyCode for next/previous
  // and aborts the process when it sends a null keyCode to the plugin.
  RegisterHotKey(hwnd_, kHotkeyPlayPause, 0, VK_MEDIA_PLAY_PAUSE);
  RegisterHotKey(hwnd_, kHotkeyNext, 0, VK_MEDIA_NEXT_TRACK);
  RegisterHotKey(hwnd_, kHotkeyPrevious, 0, VK_MEDIA_PREV_TRACK);
}

void StudioTray::DestroyTray() {
  if (added_) {
    Shell_NotifyIcon(NIM_DELETE, &nid_);
    added_ = false;
  }
  if (menu_ != nullptr) {
    DestroyMenu(menu_);
    menu_ = nullptr;
  }
}

StudioTray::~StudioTray() {
  DestroyTray();
  if (hwnd_ != nullptr) {
    UnregisterHotKey(hwnd_, kHotkeyPlayPause);
    UnregisterHotKey(hwnd_, kHotkeyNext);
    UnregisterHotKey(hwnd_, kHotkeyPrevious);
  }
}

std::optional<LRESULT> StudioTray::HandleMessage(HWND hwnd, UINT message,
                                                 WPARAM wparam,
                                                 LPARAM lparam) {
  if (message == WM_HOTKEY) {
    switch (static_cast<int>(wparam)) {
      case kHotkeyPlayPause:
        Notify("menu", flutter::EncodableValue("playPause"));
        return 0;
      case kHotkeyNext:
        Notify("menu", flutter::EncodableValue("next"));
        return 0;
      case kHotkeyPrevious:
        Notify("menu", flutter::EncodableValue("previous"));
        return 0;
      default:
        break;
    }
  } else if (message == WM_COMMAND) {
    const UINT id = LOWORD(wparam);
    if (id >= kFirstCommand) {
      const size_t index = static_cast<size_t>(id - kFirstCommand);
      if (index < command_keys_.size()) {
        Notify("menu", flutter::EncodableValue(command_keys_[index]));
        return 0;
      }
    }
  } else if (message == kCallback) {
    switch (lparam) {
      case WM_LBUTTONUP:
        Notify("click");
        return 0;
      case WM_RBUTTONUP:
        ShowMenu();
        return 0;
      default:
        break;
    }
  } else if (message == StudioShowMessage()) {
    Notify("click");
    return 0;
  }
  return std::nullopt;
}

void StudioTray::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args =
      std::get_if<flutter::EncodableMap>(call.arguments());

  if (call.method_name() == "setIcon") {
    SetIcon();
    result->Success();
    return;
  }
  if (call.method_name() == "setToolTip") {
    if (args != nullptr) {
      const auto* tip = std::get_if<std::string>(ValueOrNull(*args, "toolTip"));
      if (tip != nullptr) {
        SetToolTip(*tip);
      }
    }
    result->Success();
    return;
  }
  if (call.method_name() == "setContextMenu") {
    if (args != nullptr) {
      const auto* items =
          std::get_if<flutter::EncodableList>(ValueOrNull(*args, "items"));
      if (items != nullptr) {
        SetContextMenu(*items);
      }
    }
    result->Success();
    return;
  }
  if (call.method_name() == "popUpContextMenu") {
    ShowMenu();
    result->Success();
    return;
  }
  if (call.method_name() == "destroy") {
    DestroyTray();
    result->Success();
    return;
  }
  result->NotImplemented();
}

void StudioTray::SetIcon() {
  if (added_) {
    Shell_NotifyIcon(NIM_MODIFY, &nid_);
    return;
  }
  added_ = Shell_NotifyIcon(NIM_ADD, &nid_) == TRUE;
}

void StudioTray::SetToolTip(const std::string& tip) {
  const std::wstring wide = Utf8ToWide(tip);
  wcsncpy_s(nid_.szTip, _countof(nid_.szTip), wide.c_str(), _TRUNCATE);
  nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  if (added_) {
    Shell_NotifyIcon(NIM_MODIFY, &nid_);
  }
}

void StudioTray::SetContextMenu(const flutter::EncodableList& items) {
  if (menu_ != nullptr) {
    DestroyMenu(menu_);
  }
  menu_ = CreatePopupMenu();
  command_keys_.clear();

  for (const auto& item_value : items) {
    const auto* item = std::get_if<flutter::EncodableMap>(&item_value);
    if (item == nullptr) {
      continue;
    }
    const auto* type = std::get_if<std::string>(ValueOrNull(*item, "type"));
    if (type != nullptr && *type == "separator") {
      AppendMenuW(menu_, MF_SEPARATOR, 0, nullptr);
      command_keys_.push_back(std::string());
      continue;
    }
    const auto* key = std::get_if<std::string>(ValueOrNull(*item, "key"));
    const auto* label = std::get_if<std::string>(ValueOrNull(*item, "label"));
    const auto* disabled = std::get_if<bool>(ValueOrNull(*item, "disabled"));
    if (key == nullptr || label == nullptr) {
      continue;
    }
    UINT flags = MF_STRING;
    if (disabled != nullptr && *disabled) {
      flags |= MF_GRAYED;
    }
    const UINT id = kFirstCommand + static_cast<UINT>(command_keys_.size());
    command_keys_.push_back(*key);
    AppendMenuW(menu_, flags, id, Utf8ToWide(*label).c_str());
  }
}

void StudioTray::ShowMenu() {
  if (menu_ == nullptr || hwnd_ == nullptr) {
    return;
  }
  POINT pt;
  GetCursorPos(&pt);
  SetForegroundWindow(hwnd_);
  TrackPopupMenu(menu_, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, hwnd_,
                 nullptr);
  PostMessage(hwnd_, WM_NULL, 0, 0);
}

void StudioTray::Notify(const std::string& method,
                        flutter::EncodableValue arguments) {
  if (channel_ == nullptr) {
    return;
  }
  channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>(std::move(arguments)));
}
