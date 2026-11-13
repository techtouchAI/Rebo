// ============================================================================
//  Rebo · win32.h
//
//  One include point for the Win32 surface used by the host and the installer.
//  Keeps UNICODE/LEAN_AND_MEAN definitions, the library ORDER for static
//  linking, and the shared helper vocabulary in a single place instead of
//  duplicating them in every translation unit.
// ============================================================================
#pragma once

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>

#include <commctrl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "comctl32.lib")

#include <string>

namespace rebo {

// UTF-8 → UTF-16. Lossless for all valid input; invalid sequences become U+FFFD.
inline std::wstring widen(const std::string &utf8) {
  if (utf8.empty()) return std::wstring();
  int need = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                                 static_cast<int>(utf8.size()), nullptr, 0);
  if (need <= 0) {
    need = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                               static_cast<int>(utf8.size()), nullptr, 0);
  }
  std::wstring out(static_cast<size_t>(need), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), need);
  return out;
}

// UTF-16 → UTF-8.
inline std::string narrow(const std::wstring &utf16) {
  if (utf16.empty()) return std::string();
  int need = WideCharToMultiByte(CP_UTF8, 0, utf16.data(),
                                 static_cast<int>(utf16.size()), nullptr, 0,
                                 nullptr, nullptr);
  std::string out(static_cast<size_t>(need), '\0');
  WideCharToMultiByte(CP_UTF8, 0, utf16.data(), static_cast<int>(utf16.size()),
                      out.data(), need, nullptr, nullptr);
  return out;
}

// Directory that holds the running executable (no trailing separator).
inline std::wstring module_dir() {
  std::wstring buffer(MAX_PATH, L'\0');
  for (;;) {
    DWORD n = GetModuleFileNameW(nullptr, buffer.data(),
                                 static_cast<DWORD>(buffer.size()));
    if (n == 0) return std::wstring();
    if (n < buffer.size()) {
      buffer.resize(n);
      break;
    }
    buffer.resize(buffer.size() * 2); // path longer than MAX_PATH
  }
  size_t slash = buffer.find_last_of(L"\\/");
  return slash == std::wstring::npos ? buffer : buffer.substr(0, slash);
}

inline bool file_exists(const std::wstring &path) {
  DWORD attrs = GetFileAttributesW(path.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

// Percent-encode a Windows path into a file:// URL (UTF-8 based).
inline std::wstring file_url(const std::wstring &win_path) {
  std::string utf8 = narrow(win_path);
  for (char &c : utf8) {
    if (c == '\\') c = '/';
  }
  static const char kHex[] = "0123456789ABCDEF";
  std::string out = "file:///";
  for (unsigned char c : utf8) {
    const bool safe = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                      (c >= '0' && c <= '9') || c == '/' || c == ':' ||
                      c == '.' || c == '-' || c == '_' || c == '~';
    if (safe) {
      out += static_cast<char>(c);
    } else {
      out += '%';
      out += kHex[c >> 4];
      out += kHex[c & 0x0F];
    }
  }
  return widen(out);
}

}  // namespace rebo
