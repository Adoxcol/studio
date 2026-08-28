#ifndef RUNNER_STUDIO_INSTANCE_H_
#define RUNNER_STUDIO_INSTANCE_H_

#include <windows.h>

inline constexpr wchar_t kStudioMutexName[] = L"Local\\Adoxcol.Studio.SingleInstance";
inline constexpr wchar_t kStudioWindowProp[] = L"Adoxcol.Studio";
inline constexpr wchar_t kStudioShowMessage[] = L"Adoxcol.Studio.ShowWindow";

inline UINT StudioShowMessage() {
  return RegisterWindowMessageW(kStudioShowMessage);
}

HWND FindStudioWindow();

// If another Studio is running, asks it to show and returns true.
bool ActivateExistingStudioInstance();

#endif  // RUNNER_STUDIO_INSTANCE_H_
