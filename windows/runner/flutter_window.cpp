#include "flutter_window.h"

#include <optional>

#include <atomic>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::atomic<long long> g_key_count{0};
std::atomic<long long> g_mouse_count{0};
std::atomic<long long> g_mouse_move_count{0};
std::atomic<long long> g_mouse_scroll_count{0};
std::atomic<long long> g_mouse_click_count{0};
HHOOK g_kb_hook = nullptr;
HHOOK g_mouse_hook = nullptr;

LRESULT CALLBACK LowLevelKeyboardProc(int code, WPARAM wp, LPARAM lp) {
  if (code == HC_ACTION && wp == WM_KEYDOWN) {
    g_key_count.fetch_add(1, std::memory_order_relaxed);
  }
  return CallNextHookEx(g_kb_hook, code, wp, lp);
}

LRESULT CALLBACK LowLevelMouseProc(int code, WPARAM wp, LPARAM lp) {
  if (code == HC_ACTION) {
    g_mouse_count.fetch_add(1, std::memory_order_relaxed);
    switch (wp) {
      case WM_MOUSEMOVE:
        g_mouse_move_count.fetch_add(1, std::memory_order_relaxed);
        break;
      case WM_MOUSEWHEEL:
      case WM_MOUSEHWHEEL:
        g_mouse_scroll_count.fetch_add(1, std::memory_order_relaxed);
        break;
      case WM_LBUTTONDOWN:
      case WM_RBUTTONDOWN:
      case WM_MBUTTONDOWN:
      case WM_XBUTTONDOWN:
        g_mouse_click_count.fetch_add(1, std::memory_order_relaxed);
        break;
      default:
        break;
    }
  }
  return CallNextHookEx(g_mouse_hook, code, wp, lp);
}

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_platform_channel;

void NotifyDartSuspendOrTerminate(flutter::FlutterEngine* engine) {
  if (!engine) {
    return;
  }
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      lifecycle_channel;
  if (!lifecycle_channel) {
    lifecycle_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "com.zulutime.tracker/lifecycle",
            &flutter::StandardMethodCodec::GetInstance());
  }
  lifecycle_channel->InvokeMethod(
      "suspendOrTerminate",
      std::make_unique<flutter::EncodableValue>());
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  g_platform_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.zulutime.tracker/platform",
          &flutter::StandardMethodCodec::GetInstance());
  g_platform_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getKeyboardCountAndReset") {
          long long c = g_key_count.exchange(0);
          result->Success(flutter::EncodableValue(static_cast<int>(c)));
        } else if (call.method_name() == "getPointerCountAndReset") {
          long long c = g_mouse_count.exchange(0);
          result->Success(flutter::EncodableValue(static_cast<int>(c)));
        } else if (call.method_name() == "getPointerBreakdownAndReset") {
          const int moves = static_cast<int>(g_mouse_move_count.exchange(0));
          const int scroll = static_cast<int>(g_mouse_scroll_count.exchange(0));
          const int clicks = static_cast<int>(g_mouse_click_count.exchange(0));
          flutter::EncodableMap out;
          out[flutter::EncodableValue("moves")] = flutter::EncodableValue(moves);
          out[flutter::EncodableValue("scroll")] = flutter::EncodableValue(scroll);
          out[flutter::EncodableValue("clicks")] = flutter::EncodableValue(clicks);
          result->Success(flutter::EncodableValue(out));
        } else if (call.method_name() == "startKeyboardMonitoring") {
          if (!g_kb_hook) {
            g_kb_hook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                         GetModuleHandle(nullptr), 0);
          }
          if (!g_mouse_hook) {
            g_mouse_hook = SetWindowsHookEx(WH_MOUSE_LL, LowLevelMouseProc,
                                              GetModuleHandle(nullptr), 0);
          }
          result->Success(flutter::EncodableValue(static_cast<bool>(
              g_kb_hook || g_mouse_hook)));
        } else if (call.method_name() == "stopKeyboardMonitoring") {
          if (g_kb_hook) {
            UnhookWindowsHookEx(g_kb_hook);
            g_kb_hook = nullptr;
          }
          if (g_mouse_hook) {
            UnhookWindowsHookEx(g_mouse_hook);
            g_mouse_hook = nullptr;
          }
          result->Success();
        } else if (call.method_name() == "openPrivacySettings") {
          ShellExecuteW(nullptr, L"open", L"ms-settings:privacy", nullptr,
                        nullptr, SW_SHOWNORMAL);
          result->Success();
        } else if (call.method_name() == "captureWorkAreaToFile") {
          // Reserved for foreground-window capture; Dart falls back to full-screen PNG.
          result->Success(flutter::EncodableValue(false));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (g_kb_hook) {
    UnhookWindowsHookEx(g_kb_hook);
    g_kb_hook = nullptr;
  }
  if (g_mouse_hook) {
    UnhookWindowsHookEx(g_mouse_hook);
    g_mouse_hook = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_POWERBROADCAST:
      if (flutter_controller_ && wparam == PBT_APMSUSPEND) {
        NotifyDartSuspendOrTerminate(flutter_controller_->engine());
      }
      break;
    case WM_ENDSESSION:
      if (flutter_controller_ && wparam == TRUE) {
        NotifyDartSuspendOrTerminate(flutter_controller_->engine());
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
