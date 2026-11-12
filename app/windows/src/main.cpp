// ============================================================================
//  Rebo · Windows host
//
//  A native Win32 window hosting the Microsoft Edge WebView2 runtime through
//  a self-built loader (see loader/webview2loader.cpp).  The whole UI lives in
//  ./www next to the executable and is opened with a file:// URL, so the app
//  works completely offline.
//
//  No third-party runtime is bundled: WebView2 is a Windows component that is
//  preinstalled on Windows 11 and delivered by Edge on Windows 10.
// ============================================================================
#define WEBVIEW_MSWEBVIEW2_BUILTIN_IMPL 0
#define WEBVIEW_MSWEBVIEW2_EXPLICIT_LINK 0
#include "webview.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>

#include <string>
#include <vector>

// ---- WebView2 loader imports (resolved from WebView2Loader.dll) ------------
typedef struct ICoreWebView2EnvironmentOptions ICoreWebView2EnvironmentOptions;
typedef struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;

typedef HRESULT(WINAPI *PFN_CreateEnv)(PCWSTR, PCWSTR,
                                       ICoreWebView2EnvironmentOptions *,
                                       ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);
typedef HRESULT(WINAPI *PFN_GetVersion)(PCWSTR, LPWSTR *);

static PFN_CreateEnv g_create_env = nullptr;
static PFN_GetVersion g_get_version = nullptr;
static HMODULE g_loader = nullptr;

extern "C" HRESULT WINAPI CreateCoreWebView2EnvironmentWithOptions(
    PCWSTR a, PCWSTR b, ICoreWebView2EnvironmentOptions *c,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *d) {
  if (!g_create_env) {
    g_loader = LoadLibraryW(L"WebView2Loader.dll");
    if (g_loader) {
      g_create_env = reinterpret_cast<PFN_CreateEnv>(
          GetProcAddress(g_loader, "CreateCoreWebView2EnvironmentWithOptions"));
      g_get_version = reinterpret_cast<PFN_GetVersion>(GetProcAddress(
          g_loader, "GetAvailableCoreWebView2BrowserVersionString"));
    }
  }
  if (!g_create_env) {
    return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  }
  return g_create_env(a, b, c, d);
}

extern "C" HRESULT WINAPI GetAvailableCoreWebView2BrowserVersionString(
    PCWSTR a, LPWSTR *b) {
  if (!g_get_version) {
    if (!g_loader) {
      g_loader = LoadLibraryW(L"WebView2Loader.dll");
      if (g_loader) {
        g_get_version = reinterpret_cast<PFN_GetVersion>(GetProcAddress(
            g_loader, "GetAvailableCoreWebView2BrowserVersionString"));
      }
    }
  }
  if (!g_get_version) {
    if (b) *b = nullptr;
    return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  }
  return g_get_version(a, b);
}

// ---------------------------------------------------------------------------
static std::wstring module_dir() {
  wchar_t path[MAX_PATH] = {0};
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  PathRemoveFileSpecW(path);
  return std::wstring(path);
}

static void show_error(const wchar_t *text) {
  MessageBoxW(nullptr, text, L"ريبو — التربية الفنية",
              MB_OK | MB_ICONWARNING);
}

static bool file_exists(const std::wstring &p) {
  DWORD a = GetFileAttributesW(p.c_str());
  return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

static std::wstring to_file_url(const std::wstring &win_path) {
  std::wstring p = win_path;
  for (auto &c : p) {
    if (c == L'\\') c = L'/';
  }
  // percent-encode spaces and non-ascii (UTF-8)
  std::string narrow;
  int need = WideCharToMultiByte(CP_UTF8, 0, p.c_str(), -1, nullptr, 0, nullptr,
                                 nullptr);
  narrow.resize(need > 0 ? need - 1 : 0);
  if (need > 0) {
    WideCharToMultiByte(CP_UTF8, 0, p.c_str(), -1, &narrow[0], need, nullptr,
                        nullptr);
  }
  std::string out = "file:///";
  static const char *hex = "0123456789ABCDEF";
  for (unsigned char c : narrow) {
    bool safe = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                (c >= '0' && c <= '9') || c == '/' || c == ':' || c == '.' ||
                c == '-' || c == '_' || c == '~';
    if (safe) {
      out += static_cast<char>(c);
    } else {
      out += '%';
      out += hex[c >> 4];
      out += hex[c & 15];
    }
  }
  // widen back
  int wlen = MultiByteToWideChar(CP_UTF8, 0, out.c_str(), -1, nullptr, 0);
  std::wstring wide(wlen > 0 ? wlen - 1 : 0, L'\0');
  if (wlen > 0) {
    MultiByteToWideChar(CP_UTF8, 0, out.c_str(), -1, &wide[0], wlen);
  }
  return wide;
}

static std::string narrow(const std::wstring &w) {
  int len = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string s(len > 0 ? len - 1 : 0, '\0');
  if (len > 0) {
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, &s[0], len, nullptr, nullptr);
  }
  return s;
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::wstring dir = module_dir();
  std::wstring www = dir + L"\\www";
  std::wstring index = www + L"\\index.html";

  if (!file_exists(index)) {
    show_error(L"لم يتم العثور على ملفات المحتوى بجانب التشغيل\n"
               L"(www\\index.html).\n\n"
               L"تأكّد من أن مجلد www موجود في نفس مجلد التطبيق.");
    return 1;
  }

  SetCurrentDirectoryW(dir.c_str());

  // Probe the runtime early so we can explain what to install when missing
  // instead of opening an empty window.
  {
    LPWSTR version = nullptr;
    HRESULT hr = GetAvailableCoreWebView2BrowserVersionString(nullptr, &version);
    if (version) CoTaskMemFree(version);
    if (FAILED(hr)) {
      int answer = MessageBoxW(
          nullptr,
          L"يتطلب «ريبو» مكوّن Microsoft Edge WebView2 Runtime،\n"
          L"وهو مكوّن مجاني من شركة Microsoft، مثبّت افتراضيًا في Windows 11\n"
          L"ويأتي مع متصفح Edge في Windows 10.\n\n"
          L"هل تريد فتح صفحة التنزيل الرسمية الآن؟",
          L"ريبو — التربية الفنية", MB_YESNO | MB_ICONINFORMATION);
      if (answer == IDYES) {
        ShellExecuteW(nullptr, L"open",
                      L"https://developer.microsoft.com/microsoft-edge/webview2/",
                      nullptr, nullptr, SW_SHOWNORMAL);
      }
      CoUninitialize();
      return 2;
    }
  }

  // webview.h keeps the WebView2 profile in %APPDATA%\<exe name>, so reading
  // progress and preferences persist between runs.

  webview::webview w(false, nullptr);
  w.set_title("ريبو · التربية الفنية — المرحلة المتوسطة");
  w.set_size(1240, 860, WEBVIEW_HINT_NONE);
  w.set_size(760, 560, WEBVIEW_HINT_MIN);
  std::wstring url = to_file_url(index);
  w.navigate(narrow(url));
  w.run();

  if (g_loader) FreeLibrary(g_loader);
  CoUninitialize();
  return 0;
}
