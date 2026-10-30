/* RGSS3 is a 32-bit process. No CRT, no background process, no global hooks. */
#include <windows.h>
int __stdcall UIDestroy(void);
static HWND game;
static WNDPROC previous;
static int enabled, wheel, head, tail;
static unsigned int characters[256];
__declspec(dllexport) int __stdcall Keyboard(unsigned char *keys) {
    int i;
    for (i=0;i<256;i++) keys[i]=(GetAsyncKeyState(i)&0x8000) ? 1 : 0;
    return 1;
}
static LRESULT CALLBACK intercept(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (enabled && msg == WM_MOUSEWHEEL) { wheel += (short)HIWORD(wp); return 0; }
    if (enabled && msg == WM_CHAR) {
        int next = (head + 1) & 255;
        if (next != tail) { characters[head] = (unsigned int)wp; head = next; }
        return 0;
    }
    if (msg == WM_KILLFOCUS) { wheel = 0; head = tail = 0; }
    return IsWindowUnicode(hwnd) ? CallWindowProcW(previous, hwnd, msg, wp, lp)
                                 : CallWindowProcA(previous, hwnd, msg, wp, lp);
}
__declspec(dllexport) int __stdcall Attach(HWND hwnd) {
    if (game == hwnd && previous) return 1;
    if (previous && !IsWindow(game)) { previous = 0; game = 0; }
    if (previous || !IsWindow(hwnd)) return 0;
    SetLastError(0);
    previous = (WNDPROC)SetWindowLongPtrW(hwnd, GWLP_WNDPROC, (LONG_PTR)intercept);
    if (!previous) return 0;
    game = hwnd;
    return 1;
}
__declspec(dllexport) int __stdcall Enable(int value) {
    if (!value) UIDestroy();
    enabled = value; wheel = 0; head = tail = 0; return 1;
}
__declspec(dllexport) int __stdcall Wheel(void) { int result = wheel; wheel = 0; return result; }
__declspec(dllexport) int __stdcall Character(void) {
    unsigned int result;
    if (tail == head) return 0;
    result = characters[tail]; tail = (tail + 1) & 255; return (int)result;
}
__declspec(dllexport) int __stdcall UnicodeWindow(void) { return IsWindowUnicode(game); }
__declspec(dllexport) int __stdcall Paste(void) {
    HANDLE data; const WCHAR *text; int i;
    if (!OpenClipboard(game)) return 0;
    data = GetClipboardData(CF_UNICODETEXT);
    text = data ? (const WCHAR *)GlobalLock(data) : 0;
    if (text) {
        for (i = 0; text[i] && ((head + 1) & 255) != tail; ++i) {
            characters[head] = text[i]; head = (head + 1) & 255;
        }
        GlobalUnlock(data);
    }
    CloseClipboard(); return text != 0;
}
__declspec(dllexport) int __stdcall Copy(const WCHAR *text, int bytes) {
    HANDLE data; WCHAR *destination; int i;
    if (bytes < 0 || bytes > 65536 || !OpenClipboard(game)) return 0;
    data = GlobalAlloc(GMEM_MOVEABLE, bytes + 2);
    destination = data ? (WCHAR *)GlobalLock(data) : 0;
    if (!destination) { if (data) GlobalFree(data); CloseClipboard(); return 0; }
    for (i = 0; i < bytes / 2; ++i) destination[i] = text[i];
    destination[i] = 0;
    GlobalUnlock(data);
    EmptyClipboard();
    if (!SetClipboardData(CF_UNICODETEXT, data)) { GlobalFree(data); CloseClipboard(); return 0; }
    CloseClipboard(); return 1;
}
__declspec(dllexport) int __stdcall Detach(void) {
    UIDestroy();
    if (previous && IsWindow(game)) {
        if ((WNDPROC)GetWindowLongPtrW(game, GWLP_WNDPROC) != intercept) return 0;
        SetWindowLongPtrW(game, GWLP_WNDPROC, (LONG_PTR)previous);
    }
    previous = 0; game = 0; enabled = 0; return 1;
}
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) { return TRUE; }
