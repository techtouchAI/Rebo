// ============================================================================
//  Rebo · webview2loader.dll
//
//  A minimal, source-built stand-in for Microsoft's WebView2Loader.
//  It exports the single symbol the host program needs and forwards the call
//  to the *installed* WebView2 Runtime (Edge), which ships EmbeddedBrowserWebView.dll
//  inside  %ProgramFiles(x86)%\Microsoft\EdgeWebView\Application\<version>.
//
//  No Microsoft binaries are redistributed with Rebo: the runtime is already
//  present on Windows 11 and on Windows 10 machines that run Edge.
// ============================================================================
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <string>
#include <vector>

// --- the two COM-style declarations we need (kept minimal on purpose) -------
typedef struct ICoreWebView2EnvironmentOptions ICoreWebView2EnvironmentOptions;
typedef struct ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;

typedef HRESULT(WINAPI *CreateWebViewEnvironmentWithOptionsInternal_t)(
    bool, int /*webview2_runtime_type*/, PCWSTR, ICoreWebView2EnvironmentOptions *,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);

typedef HRESULT(WINAPI *GetAvailableCoreWebView2BrowserVersionString_t)(PCWSTR,
                                                                      LPWSTR *);

static const wchar_t *kRuntimeGuid =
    L"{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"; // WebView2 Runtime client id

static bool read_version_from(HKEY root, const std::wstring &key,
                              std::wstring &out) {
  HKEY h = nullptr;
  if (RegOpenKeyExW(root, key.c_str(), 0, KEY_READ | KEY_WOW64_32KEY, &h) !=
      ERROR_SUCCESS) {
    return false;
  }
  wchar_t buf[128];
  DWORD len = sizeof(buf), type = 0;
  bool ok = false;
  if (RegQueryValueExW(h, L"pv", nullptr, &type, reinterpret_cast<LPBYTE>(buf),
                       &len) == ERROR_SUCCESS &&
      (type == REG_SZ || type == REG_EXPAND_SZ)) {
    out.assign(buf, len / sizeof(wchar_t));
    while (!out.empty() && out.back() == L'\0') {
      out.pop_back();
    }
    ok = !out.empty() && out != L"0.0.0.0";
  }
  RegCloseKey(h);
  return ok;
}

// Locate EmbeddedBrowserWebView.dll of the installed runtime.
static bool find_runtime_dll(std::wstring &dll_path) {
  std::wstring version;
  bool have_version =
      read_version_from(HKEY_LOCAL_MACHINE,
                        std::wstring(L"SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\") +
                            kRuntimeGuid,
                        version) ||
      read_version_from(HKEY_CURRENT_USER,
                        std::wstring(L"SOFTWARE\\Microsoft\\EdgeUpdate\\Clients\\") +
                            kRuntimeGuid,
                        version);

  std::vector<std::wstring> roots;
  wchar_t pf[MAX_PATH] = {0};
  if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_PROGRAM_FILESX86, nullptr, 0, pf))) {
    roots.push_back(std::wstring(pf) + L"\\Microsoft\\EdgeWebView\\Application");
  }
  if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_PROGRAM_FILES, nullptr, 0, pf))) {
    roots.push_back(std::wstring(pf) + L"\\Microsoft\\EdgeWebView\\Application");
  }

  auto exists = [](const std::wstring &p) {
    DWORD a = GetFileAttributesW(p.c_str());
    return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
  };

  if (have_version) {
    for (auto &r : roots) {
      std::wstring p = r + L"\\" + version + L"\\EmbeddedBrowserWebView.dll";
      if (exists(p)) {
        dll_path = p;
        return true;
      }
    }
  }
  // Fall back to the newest directory that contains the DLL.
  for (auto &r : roots) {
    std::wstring pattern = r + L"\\*";
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(pattern.c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) continue;
    std::wstring best;
    do {
      if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
      if (fd.cFileName[0] == L'.') continue;
      std::wstring p = r + L"\\" + fd.cFileName + L"\\EmbeddedBrowserWebView.dll";
      if (!exists(p)) continue;
      std::wstring dir = fd.cFileName;
      int a = _wtoi(dir.c_str());
      int b = best.empty() ? -1 : _wtoi(best.c_str());
      if (a > b) best = dir;
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    if (!best.empty()) {
      dll_path = r + L"\\" + best + L"\\EmbeddedBrowserWebView.dll";
      return true;
    }
  }
  return false;
}

static HMODULE runtime_module() {
  static HMODULE mod = nullptr;
  static bool tried = false;
  if (!tried) {
    tried = true;
    std::wstring path;
    if (find_runtime_dll(path)) {
      mod = LoadLibraryW(path.c_str());
    }
  }
  return mod;
}

extern "C" __declspec(dllexport) HRESULT WINAPI
CreateCoreWebView2EnvironmentWithOptions(
    PCWSTR browser_executable_folder, PCWSTR user_data_folder,
    ICoreWebView2EnvironmentOptions *environment_options,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *handler) {
  HMODULE mod = runtime_module();
  if (!mod) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  auto fn = reinterpret_cast<CreateWebViewEnvironmentWithOptionsInternal_t>(
      GetProcAddress(mod, "CreateWebViewEnvironmentWithOptionsInternal"));
  if (!fn) return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND);
  // runtime_type 0 == installed (as opposed to 1 == embedded/fixed)
  return fn(true, 0, user_data_folder, environment_options, handler);
}

extern "C" __declspec(dllexport) HRESULT WINAPI
GetAvailableCoreWebView2BrowserVersionString(PCWSTR browser_executable_folder,
                                             LPWSTR *version_info) {
  // Ask the runtime itself when possible.
  HMODULE mod = runtime_module();
  if (mod) {
    auto fn = reinterpret_cast<GetAvailableCoreWebView2BrowserVersionString_t>(
        GetProcAddress(mod, "GetAvailableCoreWebView2BrowserVersionString"));
    if (fn) return fn(browser_executable_folder, version_info);
  }
  if (version_info) *version_info = nullptr;
  return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
}

extern "C" __declspec(dllexport) HRESULT WINAPI DllCanUnloadNow(void) {
  return S_FALSE;
}

BOOL WINAPI DllMain(HINSTANCE, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    DisableThreadLibraryCalls(nullptr);
  }
  return TRUE;
}
