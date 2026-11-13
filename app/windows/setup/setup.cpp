// ============================================================================
//  Rebo · setup.cpp — per-user Windows installer (no admin required)
//
//  • payload : a *stored* (uncompressed) zip embedded in the executable as
//              RCDATA 100, so installation needs no decompression library and
//              the extracted bytes are identical to the portable build
//  • target  : %LOCALAPPDATA%\Programs\Rebo
//  • effects : Start-Menu + Desktop shortcuts (IShellLink), an uninstall entry
//              under HKCU\...\Uninstall\Rebo, and a copy of itself as
//              uninstall.exe
//  • flags   : /S or --silent for unattended install, --uninstall to remove
//
//  Plain Win32 only: the installer has no runtime dependency beyond the DLLs
//  that ship with Windows, and it never asks for elevation.
// ============================================================================
#include "../src/win32.h"

#include <objidl.h>

#include <string>
#include <vector>

#ifndef REBO_VERSION_STRING
#define REBO_VERSION_STRING "1.0.0"
#endif

namespace {

constexpr WORD kPayloadResourceId = 100;
constexpr wchar_t kAppName[] = L"Rebo — التربية الفنية";
constexpr wchar_t kShortcutName[] = L"ريبو.lnk";
constexpr wchar_t kRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Rebo";

// ------------------------------------------------------------------ state
HWND g_window = nullptr;
HWND g_progress = nullptr;
HWND g_status = nullptr;
bool g_silent = false;
int g_scale = 1;  // device pixels per 96-DPI logical pixel

int dp(int logical) { return logical * g_scale; }

void pump_messages() {
  MSG message;
  while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
}

void set_status(const wchar_t *text, int percent) {
  if (g_silent || !g_window) return;
  if (g_status) SetWindowTextW(g_status, text);
  if (g_progress) {
    SendMessageW(g_progress, PBM_SETPOS, static_cast<WPARAM>(percent < 0 ? 0 : percent), 0);
  }
  pump_messages();
}

// ------------------------------------------------------------------- paths
std::wstring known_folder(const KNOWNFOLDERID &id) {
  PWSTR raw = nullptr;
  std::wstring result;
  if (SUCCEEDED(SHGetKnownFolderPath(id, 0, nullptr, &raw)) && raw) {
    result = raw;
    CoTaskMemFree(raw);
  }
  return result;
}

std::wstring install_dir() {
  std::wstring base = known_folder(FOLDERID_LocalAppData);
  if (base.empty()) base = known_folder(FOLDERID_RoamingAppData);
  return base + L"\\Programs\\Rebo";
}

// mkdir -p
bool ensure_dir(const std::wstring &path) {
  if (path.empty()) return true;
  const DWORD attrs = GetFileAttributesW(path.c_str());
  if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY)) {
    return true;
  }
  const size_t slash = path.find_last_of(L"\\/");
  if (slash != std::wstring::npos && slash > 2) {
    ensure_dir(path.substr(0, slash));
  }
  CreateDirectoryW(path.c_str(), nullptr);
  const DWORD after = GetFileAttributesW(path.c_str());
  return after != INVALID_FILE_ATTRIBUTES && (after & FILE_ATTRIBUTE_DIRECTORY);
}

// ------------------------------------------------------------------ window
LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND: {
      RECT area;
      GetClientRect(window, &area);
      HBRUSH brush = CreateSolidBrush(RGB(18, 22, 31));
      FillRect(reinterpret_cast<HDC>(wparam), &area, brush);
      DeleteObject(brush);
      return 1;
    }
    case WM_CTLCOLORSTATIC: {
      HDC dc = reinterpret_cast<HDC>(wparam);
      SetBkMode(dc, TRANSPARENT);
      SetTextColor(dc, RGB(232, 236, 244));
      return reinterpret_cast<LRESULT>(GetStockObject(NULL_BRUSH));
    }
    case WM_CLOSE:
      return 0;  // install in progress: the window is not dismissible
    default:
      return DefWindowProcW(window, message, wparam, lparam);
  }
}

HFONT make_font(int logical_height, int weight) {
  return CreateFontW(-dp(logical_height), 0, 0, 0, weight, 0, 0, 0,
                     DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                     CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
}

void create_window() {
  if (g_silent) return;

  const HINSTANCE instance = GetModuleHandleW(nullptr);
  WNDCLASSEXW wc = {sizeof(wc)};
  wc.lpfnWndProc = window_proc;
  wc.hInstance = instance;
  wc.lpszClassName = L"ReboSetupWindow";
  wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(1));
  wc.hbrBackground = CreateSolidBrush(RGB(18, 22, 31));
  RegisterClassExW(&wc);

  const int width = dp(540);
  const int height = dp(210);
  const int x = (GetSystemMetrics(SM_CXSCREEN) - width) / 2;
  const int y = (GetSystemMetrics(SM_CYSCREEN) - height) / 2;
  g_window = CreateWindowExW(
      WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, L"ReboSetupWindow", L"تثبيت ريبو",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE, x, y, width, height,
      nullptr, nullptr, instance, nullptr);

  const HFONT title_font = make_font(19, FW_BOLD);
  const HFONT body_font = make_font(15, FW_NORMAL);

  auto make_label = [&](const wchar_t *text, int top, HFONT font) {
    HWND label = CreateWindowExW(0, L"STATIC", text, WS_CHILD | WS_VISIBLE | SS_RIGHT,
                                 dp(24), dp(top), width - dp(48), dp(24), g_window,
                                 nullptr, instance, nullptr);
    SendMessageW(label, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE);
    return label;
  };

  make_label(L"ريبو · التربية الفنية", 18, title_font);
  g_status = make_label(L"جارٍ التحضير…", 60, body_font);

  g_progress = CreateWindowExW(0, PROGRESS_CLASSW, nullptr, WS_CHILD | WS_VISIBLE,
                               dp(24), dp(104), width - dp(48), dp(16), g_window,
                               nullptr, instance, nullptr);
  SendMessageW(g_progress, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
  SendMessageW(g_progress, PBM_SETBARCOLOR, 0, RGB(87, 195, 167));

  make_label(L"يُثبَّت التطبيق في مجلد المستخدم، دون الحاجة إلى صلاحيات المدير.",
             136, body_font);

  ShowWindow(g_window, SW_SHOW);
  UpdateWindow(g_window);
  pump_messages();
}

// --------------------------------------------------------------- shortcuts
void make_shortcut(const std::wstring &lnk_path, const std::wstring &target,
                   const std::wstring &workdir, const std::wstring &description) {
  IShellLinkW *link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IShellLinkW, reinterpret_cast<void **>(&link)))) {
    return;
  }
  link->SetPath(target.c_str());
  link->SetWorkingDirectory(workdir.c_str());
  link->SetDescription(description.c_str());
  link->SetIconLocation(target.c_str(), 0);

  IPersistFile *file = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_IPersistFile, reinterpret_cast<void **>(&file)))) {
    file->Save(lnk_path.c_str(), TRUE);
    file->Release();
  }
  link->Release();
}

// ------------------------------------------------------------- zip payload
struct ZipEntry {
  std::wstring path;
  const unsigned char *data = nullptr;
  DWORD size = 0;
};

// Parse the stored-zip payload out of RCDATA without any external library.
bool read_payload(std::vector<ZipEntry> &entries) {
  HRSRC resource = FindResourceW(nullptr, MAKEINTRESOURCEW(kPayloadResourceId), RT_RCDATA);
  if (!resource) return false;
  HGLOBAL handle = LoadResource(nullptr, resource);
  if (!handle) return false;
  const unsigned char *base = static_cast<const unsigned char *>(LockResource(handle));
  const DWORD total = SizeofResource(nullptr, resource);
  if (!base || total < 22) return false;

  DWORD offset = 0;
  while (offset + 30 <= total) {
    if (base[offset] != 'P' || base[offset + 1] != 'K' || base[offset + 2] != 0x03 ||
        base[offset + 3] != 0x04) {
      return false;  // not a local file header: end of the entry list
    }
    const WORD method = *reinterpret_cast<const WORD *>(base + offset + 8);
    const DWORD compressed = *reinterpret_cast<const DWORD *>(base + offset + 18);
    const DWORD uncompressed = *reinterpret_cast<const DWORD *>(base + offset + 22);
    const WORD name_len = *reinterpret_cast<const WORD *>(base + offset + 26);
    const WORD extra_len = *reinterpret_cast<const WORD *>(base + offset + 28);
    if (method != 0) return false;  // the payload must be stored, not deflated
    if (offset + 30 + name_len + extra_len + compressed > total) return false;

    ZipEntry entry;
    entry.path = rebo::widen(
        std::string(reinterpret_cast<const char *>(base + offset + 30), name_len));
    entry.data = base + offset + 30 + name_len + extra_len;
    entry.size = uncompressed;
    entries.push_back(entry);
    offset += 30 + name_len + extra_len + compressed;
  }
  return !entries.empty();
}

bool extract_all(const std::wstring &destination) {
  std::vector<ZipEntry> entries;
  if (!read_payload(entries)) return false;

  size_t written_files = 0;
  for (const ZipEntry &entry : entries) {
    std::wstring full = destination + L"\\" + entry.path;
    for (wchar_t &ch : full) {
      if (ch == L'/') ch = L'\\';
    }
    if (!full.empty() && full.back() == L'\\') {
      ensure_dir(full);
      continue;
    }
    ensure_dir(full.substr(0, full.find_last_of(L'\\')));

    HANDLE file = CreateFileW(full.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    const BOOL ok = WriteFile(file, entry.data, entry.size, &written, nullptr);
    CloseHandle(file);
    if (!ok || written != entry.size) return false;

    ++written_files;
    set_status(L"جارٍ تثبيت ملفات التطبيق…",
               static_cast<int>(10 + 80.0 * written_files / entries.size()));
  }
  return true;
}

// --------------------------------------------------------------- uninstall
void remove_tree(const std::wstring &dir) {
  WIN32_FIND_DATAW data;
  HANDLE find = FindFirstFileW((dir + L"\\*").c_str(), &data);
  if (find == INVALID_HANDLE_VALUE) return;
  do {
    const wchar_t *name = data.cFileName;
    if (!lstrcmpW(name, L".") || !lstrcmpW(name, L"..")) continue;
    const std::wstring path = dir + L"\\" + name;
    if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      remove_tree(path);
      RemoveDirectoryW(path.c_str());
    } else {
      SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
      DeleteFileW(path.c_str());
    }
  } while (FindNextFileW(find, &data));
  FindClose(find);
}

int run_uninstall() {
  const std::wstring dir = install_dir();
  DeleteFileW((known_folder(FOLDERID_Programs) + L"\\" + kShortcutName).c_str());
  DeleteFileW((known_folder(FOLDERID_Desktop) + L"\\" + kShortcutName).c_str());

  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRegKey, 0, KEY_ALL_ACCESS, &key) == ERROR_SUCCESS) {
    RegDeleteTreeW(key, nullptr);
    RegCloseKey(key);
  }

  // The running image cannot delete itself; move it aside, wipe the folder,
  // then schedule the leftover copy for deletion at reboot.
  const std::wstring self = rebo::module_dir() + L"\\uninstall.exe";
  const std::wstring parked = dir + L"\\uninstall.old.exe";
  MoveFileExW(self.c_str(), parked.c_str(), MOVEFILE_REPLACE_EXISTING);

  // Remove everything except the parked uninstaller, then delete that last.
  WIN32_FIND_DATAW data;
  HANDLE find = FindFirstFileW((dir + L"\\*").c_str(), &data);
  if (find != INVALID_HANDLE_VALUE) {
    do {
      const wchar_t *name = data.cFileName;
      if (!lstrcmpW(name, L".") || !lstrcmpW(name, L"..")) continue;
      const std::wstring path = dir + L"\\" + name;
      if (!lstrcmpiW(path.c_str(), parked.c_str())) continue;
      if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        remove_tree(path);
        RemoveDirectoryW(path.c_str());
      } else {
        SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
        DeleteFileW(path.c_str());
      }
    } while (FindNextFileW(find, &data));
    FindClose(find);
  }
  MoveFileExW(parked.c_str(), nullptr, MOVEFILE_DELAY_UNTIL_REBOOT);
  RemoveDirectoryW(dir.c_str());

  MessageBoxW(nullptr, L"تمت إزالة «ريبو» من هذا الجهاز.", kAppName,
              MB_OK | MB_ICONINFORMATION);
  return 0;
}

// ------------------------------------------------------------------ setup
void register_uninstaller(const std::wstring &dir) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRegKey, 0, nullptr, 0, KEY_WRITE, nullptr,
                      &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  auto set_string = [&](const wchar_t *name, const std::wstring &value) {
    RegSetValueExW(key, name, 0, REG_SZ,
                   reinterpret_cast<const BYTE *>(value.c_str()),
                   static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  };

  const std::wstring exe = dir + L"\\Rebo.exe";
  set_string(L"DisplayName", kAppName);
  set_string(L"DisplayVersion", rebo::widen(REBO_VERSION_STRING));
  set_string(L"Publisher", L"TechTouch AI");
  set_string(L"DisplayIcon", exe + L",0");
  set_string(L"InstallLocation", dir);
  set_string(L"UninstallString", L"\"" + dir + L"\\uninstall.exe\" --uninstall");
  set_string(L"QuietUninstallString", L"\"" + dir + L"\\uninstall.exe\" --uninstall /S");

  const DWORD one = 1;
  RegSetValueExW(key, L"NoModify", 0, REG_DWORD,
                 reinterpret_cast<const BYTE *>(&one), sizeof(one));
  RegSetValueExW(key, L"NoRepair", 0, REG_DWORD,
                 reinterpret_cast<const BYTE *>(&one), sizeof(one));
  RegCloseKey(key);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0;
  LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  bool uninstall = false;
  for (int i = 1; i < argc; ++i) {
    if (!lstrcmpiW(argv[i], L"/S") || !lstrcmpiW(argv[i], L"--silent")) g_silent = true;
    if (!lstrcmpiW(argv[i], L"--uninstall")) uninstall = true;
  }
  LocalFree(argv);

  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {
    MessageBoxW(nullptr, L"تعذّر تهيئة مكوّنات COM.", kAppName, MB_OK | MB_ICONERROR);
    return 1;
  }
  INITCOMMONCONTROLSEX icc = {sizeof(icc), ICC_PROGRESS_CLASS};
  InitCommonControlsEx(&icc);

  if (uninstall) {
    const int result = run_uninstall();
    CoUninitialize();
    return result;
  }

  // Scale the window and fonts with the monitor's DPI (the manifest declares
  // per-monitor v2 awareness, so Windows reports the real value here).
  HDC screen = GetDC(nullptr);
  g_scale = GetDeviceCaps(screen, LOGPIXELSX) > 120 ? 2 : 1;
  ReleaseDC(nullptr, screen);

  create_window();

  const std::wstring dir = install_dir();
  set_status(L"جارٍ إنشاء مجلد التثبيت…", 5);
  if (!ensure_dir(dir)) {
    MessageBoxW(nullptr, L"تعذّر إنشاء مجلد التثبيت.", kAppName, MB_OK | MB_ICONERROR);
    CoUninitialize();
    return 1;
  }

  set_status(L"جارٍ تثبيت ملفات التطبيق…", 12);
  if (!extract_all(dir)) {
    MessageBoxW(nullptr, L"تعذّر استخراج ملفات التطبيق. قد يكون ملف التثبيت تالفًا.",
                kAppName, MB_OK | MB_ICONERROR);
    CoUninitialize();
    return 1;
  }

  set_status(L"جارٍ إنشاء الاختصارات…", 92);
  const std::wstring exe = dir + L"\\Rebo.exe";
  const std::wstring description = L"ريبو — دليل التربية الفنية للمرحلة المتوسطة";
  make_shortcut(known_folder(FOLDERID_Programs) + L"\\" + kShortcutName, exe, dir, description);
  make_shortcut(known_folder(FOLDERID_Desktop) + L"\\" + kShortcutName, exe, dir, description);

  register_uninstaller(dir);

  wchar_t self[MAX_PATH];
  GetModuleFileNameW(nullptr, self, MAX_PATH);
  const std::wstring uninstaller = dir + L"\\uninstall.exe";
  if (lstrcmpiW(self, uninstaller.c_str()) != 0) {
    CopyFileW(self, uninstaller.c_str(), FALSE);
  }

  set_status(L"اكتمل التثبيت.", 100);
  if (!g_silent) {
    if (g_window) DestroyWindow(g_window);
    const int answer = MessageBoxW(
        nullptr,
        L"تم تثبيت «ريبو» بنجاح.\n\n"
        L"• اختصار على سطح المكتب وفي قائمة ابدأ\n"
        L"• إزالة التطبيق من: الإعدادات ← التطبيقات\n\n"
        L"هل تريد تشغيل التطبيق الآن؟",
        kAppName, MB_YESNO | MB_ICONINFORMATION);
    if (answer == IDNO) {
      CoUninitialize();
      return 0;
    }
  }
  ShellExecuteW(nullptr, L"open", exe.c_str(), nullptr, dir.c_str(), SW_SHOWNORMAL);
  CoUninitialize();
  return 0;
}
