// ============================================================================
//  Rebo · Windows host
//
//  A native Win32 window that hosts the Microsoft Edge WebView2 runtime
//  through a source-built loader (loader/webview2loader.cpp). The UI lives in
//  ./www next to the executable and is opened through a file:// URL, so the
//  app is fully offline.
//
//  The host deliberately keeps an explicit, human-readable startup sequence:
//      1. locate and validate the payload
//      2. probe the WebView2 runtime (friendly Arabic message + download link)
//      3. create the window and navigate
//  Any failure surfaces a specific message rather than an empty window.
// ============================================================================
#define WEBVIEW_MSWEBVIEW2_BUILTIN_IMPL 0
#define WEBVIEW_MSWEBVIEW2_EXPLICIT_LINK 0
#include "webview.h"

#include "win32.h"

#include <string>

// ---- WebView2 loader imports (resolved from WebView2Loader.dll) ------------
// Declared locally so the host does not have to pull in the whole SDK header.
typedef struct ICoreWebView2EnvironmentOptions ICoreWebView2EnvironmentOptions;
typedef struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;

typedef HRESULT(WINAPI *PFN_CreateEnv)(
    PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions *,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);
typedef HRESULT(WINAPI *PFN_GetVersion)(PCWSTR, LPWSTR *);

namespace {

HMODULE g_loader = nullptr;
PFN_CreateEnv g_create_env = nullptr;
PFN_GetVersion g_get_version = nullptr;

// Resolve both entry points once, at first use.
void resolve_loader() {
  if (g_loader) return;
  g_loader = LoadLibraryW(L"WebView2Loader.dll");
  if (!g_loader) return;
  g_create_env = reinterpret_cast<PFN_CreateEnv>(
      GetProcAddress(g_loader, "CreateCoreWebView2EnvironmentWithOptions"));
  g_get_version = reinterpret_cast<PFN_GetVersion>(
      GetProcAddress(g_loader, "GetAvailableCoreWebView2BrowserVersionString"));
}

void show_error(const wchar_t *text, UINT icon = MB_ICONWARNING) {
  MessageBoxW(nullptr, text, L"ريبو — التربية الفنية", MB_OK | icon);
}

// True when a usable WebView2 runtime is installed.
bool runtime_available() {
  resolve_loader();
  if (!g_get_version) return false;
  LPWSTR version = nullptr;
  HRESULT hr = g_get_version(nullptr, &version);
  if (version) CoTaskMemFree(version);
  return SUCCEEDED(hr);
}

}  // namespace

// The loader exports these two symbols; webview.h looks them up by name.
extern "C" HRESULT WINAPI CreateCoreWebView2EnvironmentWithOptions(
    PCWSTR browser_dir, PCWSTR user_data_dir,
    ICoreWebView2EnvironmentOptions *options,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *handler) {
  resolve_loader();
  if (!g_create_env) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  return g_create_env(browser_dir, user_data_dir, options, handler);
}

extern "C" HRESULT WINAPI GetAvailableCoreWebView2BrowserVersionString(
    PCWSTR browser_dir, LPWSTR *version) {
  resolve_loader();
  if (!g_get_version) {
    if (version) *version = nullptr;
    return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  }
  return g_get_version(browser_dir, version);
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {
    show_error(L"تعذّر تهيئة مكوّنات COM المطلوبة لعرض الواجهة.", MB_ICONERROR);
    return 3;
  }

  const std::wstring dir = rebo::module_dir();
  const std::wstring www = dir + L"\\www";
  const std::wstring index = www + L"\\index.html";

  if (!rebo::file_exists(index)) {
    show_error(
        L"لم يتم العثور على ملفات المحتوى بجانب التشغيل\n"
        L"(www\\index.html).\n\n"
        L"تأكّد من أن مجلد www موجود في نفس مجلد التطبيق، وأن التثبيت\n"
        L"لم ينقطع قبل اكتماله.");
    CoUninitialize();
    return 1;
  }

  SetCurrentDirectoryW(dir.c_str());

  if (!runtime_available()) {
    const int answer = MessageBoxW(
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

  // webview.h keeps the WebView2 profile under %LOCALAPPDATA%\<exe name>, so
  // reading progress and reader preferences persist between runs.
  webview::webview w(false, nullptr);
  w.set_title("ريبو · التربية الفنية — المرحلة المتوسطة");
  w.set_size(1240, 860, WEBVIEW_HINT_NONE);
  w.set_size(760, 560, WEBVIEW_HINT_MIN);
  w.navigate(rebo::narrow(rebo::file_url(index)));
  w.run();

  if (g_loader) FreeLibrary(g_loader);
  CoUninitialize();
  return 0;
}
