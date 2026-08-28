#include "studio_instance.h"

namespace {

struct FindData {
  HWND result = nullptr;
};

BOOL CALLBACK FindStudioProc(HWND hwnd, LPARAM lparam) {
  auto* data = reinterpret_cast<FindData*>(lparam);
  if (GetPropW(hwnd, kStudioWindowProp) != nullptr) {
    data->result = hwnd;
    return FALSE;
  }
  return TRUE;
}

}  // namespace

HWND FindStudioWindow() {
  FindData data;
  EnumWindows(FindStudioProc, reinterpret_cast<LPARAM>(&data));
  return data.result;
}

bool ActivateExistingStudioInstance() {
  HANDLE mutex = CreateMutexW(nullptr, TRUE, kStudioMutexName);
  if (mutex == nullptr) {
    return false;
  }
  if (GetLastError() != ERROR_ALREADY_EXISTS) {
    // Primary instance: leak the mutex until process exit so the name stays owned.
    return false;
  }
  CloseHandle(mutex);

  HWND hwnd = nullptr;
  for (int i = 0; i < 40; i++) {
    hwnd = FindStudioWindow();
    if (hwnd != nullptr) {
      break;
    }
    Sleep(50);
  }
  if (hwnd == nullptr) {
    return true;
  }

  AllowSetForegroundWindow(ASFW_ANY);
  PostMessageW(hwnd, StudioShowMessage(), 0, 0);
  ShowWindow(hwnd, SW_SHOW);
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  SetForegroundWindow(hwnd);
  return true;
}
