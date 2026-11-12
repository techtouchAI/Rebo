# third_party (vendored sources, unmodified)

| ملف | المشروع | الإصدار | الترخيص |
|---|---|---|---|
| `webview.h` | [webview/webview](https://github.com/webview/webview) — single-header C++ WebView | 0.10.0 | MIT |
| `webview_mingw_support.h` | webview/webview | 0.10.0 | MIT |
| `mingw/EventToken.h` | webview/webview (compatibility shim) | 0.10.0 | MIT |
| `WebView2.h` | Microsoft WebView2 SDK (MIDL-generated header) | runtime schema 1.x | Microsoft SDK license |

`WebView2.h` هو مجرّد **تعريفات واجهات** يولّدها وسطاء Microsoft (MIDL).
لا يحتوي أي ملفات ثنائية من Microsoft، ولا يُعاد توزيع `WebView2Loader.dll`
الرسمي؛ يستخدم «ريبو» بديلًا مبنيًا من المصدر في `loader/webview2loader.cpp`
يستدعي وقت التشغيل المثبّت مسبقًا على ويندوز.
