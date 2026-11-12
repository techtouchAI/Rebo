// ============================================================================
//  Rebo · setup.cpp  — per-user Windows installer (no admin required)
//
//  • payload: a *stored* (uncompressed) zip archive embedded as RCDATA
//  • installs to  %LOCALAPPDATA%\Programs\Rebo
//  • creates Start-Menu and Desktop shortcuts through IShellLink
//  • writes an uninstall entry + copies itself as uninstall.exe
//  • silently accepts  /S  (silent) and  --uninstall
//
//  Written against the plain Win32 API only, so the installer has no runtime
//  dependency besides the system DLLs that ship with Windows.
// ============================================================================
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <commctrl.h>
#include <objidl.h>

#include <string>
#include <vector>

#pragma comment(lib, "comctl32.lib")

// ------------------------------------------------------------------ helpers
static std::wstring exe_dir() {
  wchar_t p[MAX_PATH];
  GetModuleFileNameW(nullptr, p, MAX_PATH);
  PathRemoveFileSpecW(p);
  return p;
}

static bool ensure_dir(const std::wstring &p) {
  if (p.empty()) return true;
  DWORD a = GetFileAttributesW(p.c_str());
  if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) return true;
  size_t slash = p.find_last_of(L"\\/");
  if (slash != std::wstring::npos && slash > 2) ensure_dir(p.substr(0, slash));
  CreateDirectoryW(p.c_str(), nullptr);
  a = GetFileAttributesW(p.c_str());
  return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY);
}

static std::wstring profile_dir(const KNOWNFOLDERID &id) {
  wchar_t *buf = nullptr;
  std::wstring out;
  if (SUCCEEDED(SHGetKnownFolderPath(id, 0, nullptr, &buf)) && buf) {
    out = buf;
    CoTaskMemFree(buf);
  }
  return out;
}

static std::wstring install_dir() {
  std::wstring base = profile_dir(FOLDERID_LocalAppData);
  if (base.empty()) base = profile_dir(FOLDERID_RoamingAppData);
  return base + L"\\Programs\\Rebo";
}

// --------------------------------------------------------------- UI pieces
static HWND g_win = nullptr, g_bar = nullptr, g_label = nullptr;
static bool g_silent = false;

static void pump() {
  MSG msg;
  while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
}

static void set_status(const wchar_t *text, int percent) {
  if (g_silent || !g_win) return;
  if (g_label) SetWindowTextW(g_label, text);
  if (g_bar) SendMessageW(g_bar, PBM_SETPOS, (WPARAM)(percent < 0 ? 0 : percent), 0);
  pump();
}

static LRESULT CALLBACK wnd_proc(HWND h, UINT m, WPARAM w, LPARAM l) {
  switch (m) {
  case WM_CLOSE:
    return 0; // finishing install, don't let the user close the window
  case WM_CTLCOLORSTATIC: {
    HDC dc = (HDC)w;
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, RGB(232, 236, 244));
    return (LRESULT)GetStockObject(NULL_BRUSH);
  }
  }
  return DefWindowProcW(h, m, w, l);
}

static void create_window() {
  if (g_silent) return;
  HBRUSH bg = CreateSolidBrush(RGB(18, 22, 31));
  WNDCLASSEXW wc = {sizeof(wc)};
  wc.lpfnWndProc = wnd_proc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"ReboSetupWnd";
  wc.hbrBackground = bg;
  wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  wc.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(1));
  RegisterClassExW(&wc);

  int w = 520, h = 200;
  int x = (GetSystemMetrics(SM_CXSCREEN) - w) / 2;
  int y = (GetSystemMetrics(SM_CYSCREEN) - h) / 2;
  g_win = CreateWindowExW(WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, L"ReboSetupWnd",
                          L"تثبيت ريبو — التربية الفنية",
                          WS_POPUP | WS_CAPTION | WS_SYSMENU, x, y, w, h, nullptr,
                          nullptr, wc.hInstance, nullptr);
  HFONT font = CreateFontW(-18, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET,
                           OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  HFONT small = CreateFontW(-15, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
                            OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                            DEFAULT_PITCH, L"Segoe UI");

  HWND title = CreateWindowExW(0, L"STATIC", L"ريبو · التربية الفنية",
                               WS_CHILD | WS_VISIBLE | SS_RIGHT, 20, 18, 470, 26,
                               g_win, nullptr, wc.hInstance, nullptr);
  SendMessageW(title, WM_SETFONT, (WPARAM)font, TRUE);

  g_label = CreateWindowExW(0, L"STATIC", L"جارٍ التحضير…",
                            WS_CHILD | WS_VISIBLE | SS_RIGHT, 20, 58, 470, 24,
                            g_win, nullptr, wc.hInstance, nullptr);
  SendMessageW(g_label, WM_SETFONT, (WPARAM)small, TRUE);

  g_bar = CreateWindowExW(0, PROGRESS_CLASSW, nullptr, WS_CHILD | WS_VISIBLE,
                          20, 100, 470, 16, g_win, nullptr, wc.hInstance, nullptr);
  SendMessageW(g_bar, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
  SendMessageW(g_bar, PBM_SETBARCOLOR, 0, (LPARAM)RGB(87, 195, 167));

  HWND hint = CreateWindowExW(0, L"STATIC",
                              L"يُثبَّت التطبيق في مجلد المستخدم، دون الحاجة إلى صلاحيات المدير.",
                              WS_CHILD | WS_VISIBLE | SS_RIGHT, 20, 132, 470, 22,
                              g_win, nullptr, wc.hInstance, nullptr);
  SendMessageW(hint, WM_SETFONT, (WPARAM)small, TRUE);
  ShowWindow(g_win, SW_SHOW);
  UpdateWindow(g_win);
  pump();
}

// --------------------------------------------------------------- shortcuts
static void make_shortcut(const std::wstring &lnk, const std::wstring &target,
                          const std::wstring &workdir, const std::wstring &desc,
                          const std::wstring &icon) {
  IShellLinkW *link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IShellLinkW, (void **)&link)))
    return;
  link->SetPath(target.c_str());
  link->SetWorkingDirectory(workdir.c_str());
  link->SetDescription(desc.c_str());
  if (!icon.empty()) link->SetIconLocation(icon.c_str(), 0);
  IPersistFile *file = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_IPersistFile, (void **)&file))) {
    file->Save(lnk.c_str(), TRUE);
    file->Release();
  }
  link->Release();
}

// --------------------------------------------------------------- zip reader
struct ZipEntry {
  std::wstring path;
  const unsigned char *data;
  DWORD size;
};

static bool read_payload(std::vector<ZipEntry> &out) {
  HRSRC res = FindResourceW(nullptr, MAKEINTRESOURCEW(100), RT_RCDATA);
  if (!res) return false;
  HGLOBAL h = LoadResource(nullptr, res);
  if (!h) return false;
  const unsigned char *p = (const unsigned char *)LockResource(h);
  DWORD total = SizeofResource(nullptr, res);
  DWORD off = 0;
  while (off + 30 <= total) {
    if (p[off] != 0x50 || p[off + 1] != 0x4b || p[off + 2] != 0x03 ||
        p[off + 3] != 0x04)
      return false;
    WORD method = *(const WORD *)(p + off + 8);
    DWORD csize = *(const DWORD *)(p + off + 18);
    DWORD usize = *(const DWORD *)(p + off + 22);
    WORD nlen = *(const WORD *)(p + off + 26);
    WORD xlen = *(const WORD *)(p + off + 28);
    if (method != 0) return false; // installer payload must be stored
    std::string name((const char *)p + off + 30, nlen);
    ZipEntry e;
    e.path.clear();
    for (char c : name) e.path += (wchar_t)(unsigned char)c;
    e.data = p + off + 30 + nlen + xlen;
    e.size = usize;
    out.push_back(e);
    off += 30 + nlen + xlen + csize;
  }
  return true;
}

static bool extract_all(const std::wstring &dest) {
  std::vector<ZipEntry> entries;
  if (!read_payload(entries)) return false;
  int n = 0;
  for (auto &e : entries) {
    std::wstring full = dest + L"\\" + e.path;
    for (auto &c : full)
      if (c == L'/') c = L'\\';
    if (!full.empty() && (full.back() == L'\\')) {
      ensure_dir(full);
      continue;
    }
    ensure_dir(full.substr(0, full.find_last_of(L'\\')));
    HANDLE f = CreateFileW(full.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    WriteFile(f, e.data, e.size, &written, nullptr);
    CloseHandle(f);
    ++n;
    set_status(L"جارٍ تثبيت ملفات التطبيق…",
               entries.empty() ? 50 : (int)(10 + 80.0 * n / entries.size()));
  }
  return true;
}

// --------------------------------------------------------------- uninstall
static void remove_tree(const std::wstring &dir) {
  WIN32_FIND_DATAW fd;
  HANDLE h = FindFirstFileW((dir + L"\\*").c_str(), &fd);
  if (h == INVALID_HANDLE_VALUE) return;
  do {
    if (!lstrcmpW(fd.cFileName, L".") || !lstrcmpW(fd.cFileName, L"..")) continue;
    std::wstring p = dir + L"\\" + fd.cFileName;
    if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      remove_tree(p);
      RemoveDirectoryW(p.c_str());
    } else {
      SetFileAttributesW(p.c_str(), FILE_ATTRIBUTE_NORMAL);
      DeleteFileW(p.c_str());
    }
  } while (FindNextFileW(h, &fd));
  FindClose(h);
}

static int do_uninstall() {
  std::wstring dir = install_dir();
  std::wstring start = profile_dir(FOLDERID_Programs) + L"\\ريبو.lnk";
  std::wstring desk = profile_dir(FOLDERID_Desktop) + L"\\ريبو.lnk";
  DeleteFileW(start.c_str());
  DeleteFileW(desk.c_str());
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
                    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Rebo",
                    0, KEY_ALL_ACCESS, &key) == ERROR_SUCCESS) {
    RegDeleteTreeW(key, nullptr);
    RegCloseKey(key);
  }
  // delete the installed copy (the running uninstaller may stay behind)
  std::wstring self = exe_dir() + L"\\uninstall.exe";
  MoveFileExW(self.c_str(), (dir + L"\\uninstall_old.exe").c_str(),
              MOVEFILE_REPLACE_EXISTING);
  remove_tree(dir);
  MessageBoxW(nullptr, L"تمت إزالة ريبو من هذا الجهاز.", L"ريبو",
              MB_OK | MB_ICONINFORMATION);
  return 0;
}

// ------------------------------------------------------------------- setup
static void write_uninstall_entry(const std::wstring &dir) {
  HKEY key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER,
                      L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Rebo",
                      0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr) !=
      ERROR_SUCCESS)
    return;
  const std::wstring exe = dir + L"\\Rebo.exe";
  const std::wstring un = dir + L"\\uninstall.exe";
  const std::wstring icon = exe + L",0";
  const wchar_t *display = L"Rebo — التربية الفنية";
  const wchar_t *publisher = L"TechTouch AI";
  RegSetValueExW(key, L"DisplayName", 0, REG_SZ, (const BYTE *)display,
                 (DWORD)((wcslen(display) + 1) * sizeof(wchar_t)));
  RegSetValueExW(key, L"DisplayVersion", 0, REG_SZ, (const BYTE *)L"1.0.0", 12);
  RegSetValueExW(key, L"Publisher", 0, REG_SZ, (const BYTE *)publisher,
                 (DWORD)((wcslen(publisher) + 1) * sizeof(wchar_t)));
  RegSetValueExW(key, L"DisplayIcon", 0, REG_SZ, (const BYTE *)icon.c_str(),
                 (DWORD)((icon.size() + 1) * sizeof(wchar_t)));
  RegSetValueExW(key, L"InstallLocation", 0, REG_SZ, (const BYTE *)dir.c_str(),
                 (DWORD)((dir.size() + 1) * sizeof(wchar_t)));
  std::wstring cmd = L"\"" + un + L"\" --uninstall";
  RegSetValueExW(key, L"UninstallString", 0, REG_SZ, (const BYTE *)cmd.c_str(),
                 (DWORD)((cmd.size() + 1) * sizeof(wchar_t)));
  DWORD no_modify = 1;
  RegSetValueExW(key, L"NoModify", 0, REG_DWORD, (const BYTE *)&no_modify, 4);
  RegSetValueExW(key, L"NoRepair", 0, REG_DWORD, (const BYTE *)&no_modify, 4);
  RegCloseKey(key);
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0;
  LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  for (int i = 1; i < argc; i++) {
    if (!lstrcmpiW(argv[i], L"/S") || !lstrcmpiW(argv[i], L"--silent"))
      g_silent = true;
    if (!lstrcmpiW(argv[i], L"--uninstall")) {
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      return do_uninstall();
    }
  }

  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  InitCommonControls();
  create_window();

  std::wstring dir = install_dir();
  set_status(L"جارٍ إنشاء مجلد التثبيت…", 5);
  if (!ensure_dir(dir)) {
    MessageBoxW(nullptr, L"تعذّر إنشاء مجلد التثبيت.", L"ريبو", MB_OK | MB_ICONERROR);
    return 1;
  }

  set_status(L"جارٍ تثبيت ملفات التطبيق…", 12);
  if (!extract_all(dir)) {
    MessageBoxW(nullptr, L"تعذّر استخراج ملفات التطبيق.", L"ريبو",
                MB_OK | MB_ICONERROR);
    return 1;
  }

  set_status(L"جارٍ إنشاء الاختصارات…", 92);
  std::wstring exe = dir + L"\\Rebo.exe";
  make_shortcut(profile_dir(FOLDERID_Programs) + L"\\ريبو.lnk", exe, dir,
                L"ريبو — التربية الفنية للمرحلة المتوسطة", exe);
  make_shortcut(profile_dir(FOLDERID_Desktop) + L"\\ريبو.lnk", exe, dir,
                L"ريبو — التربية الفنية للمرحلة المتوسطة", exe);
  write_uninstall_entry(dir);
  {
    wchar_t self[MAX_PATH];
    GetModuleFileNameW(nullptr, self, MAX_PATH);
    std::wstring target = dir + L"\\uninstall.exe";
    if (lstrcmpiW(self, target.c_str()) != 0) {
      CopyFileW(self, target.c_str(), FALSE);
    }
  }

  set_status(L"اكتمل التثبيت.", 100);
  if (!g_silent) {
    Sleep(350);
    if (g_win) DestroyWindow(g_win);
    int r = MessageBoxW(
        nullptr,
        L"تم تثبيت «ريبو» بنجاح.\n\n"
        L"• اختصار على سطح المكتب وفي قائمة ابدأ\n"
        L"• إزالة التطبيق من: الإعدادات ← التطبيقات\n\n"
        L"هل تريد تشغيل التطبيق الآن؟",
        L"ريبو — التربية الفنية", MB_YESNO | MB_ICONINFORMATION);
    if (r == IDNO) {
      CoUninitialize();
      return 0;
    }
  }
  ShellExecuteW(nullptr, L"open", exe.c_str(), nullptr, dir.c_str(), SW_SHOWNORMAL);
  CoUninitialize();
  return 0;
}
