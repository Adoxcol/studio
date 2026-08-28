#ifndef RUNNER_STUDIO_TRAY_H_
#define RUNNER_STUDIO_TRAY_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace flutter {
class BinaryMessenger;
}

// Zero-initialized Shell_NotifyIcon wrapper. tray_manager's Windows plugin
// DestroyIcon()s a garbage HICON on first setIcon in MSVC Debug — that
// native-crashes the process as soon as the window appears.
class StudioTray {
 public:
  StudioTray(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~StudioTray();

  StudioTray(const StudioTray&) = delete;
  StudioTray& operator=(const StudioTray&) = delete;

  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  static constexpr UINT kCallback = WM_APP + 1;
  static constexpr UINT kFirstCommand = 1000;
  static constexpr int kHotkeyPlayPause = 1;
  static constexpr int kHotkeyNext = 2;
  static constexpr int kHotkeyPrevious = 3;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetIcon();
  void SetToolTip(const std::string& tip);
  void SetContextMenu(const flutter::EncodableList& items);
  void DestroyTray();
  void ShowMenu();
  void Notify(const std::string& method,
              flutter::EncodableValue arguments = flutter::EncodableValue());

  HWND hwnd_;
  NOTIFYICONDATA nid_{};
  bool added_ = false;
  HMENU menu_ = nullptr;
  std::vector<std::string> command_keys_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_STUDIO_TRAY_H_
