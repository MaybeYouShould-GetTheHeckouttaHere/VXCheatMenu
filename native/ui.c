/* Screen-resolution UI. Owned, non-activating window; no RGSS backbuffer resize. */
#define UNICODE
#include <windows.h>
typedef HANDLE (WINAPI *DpiSwitch)(HANDLE);
typedef UINT (WINAPI *DpiForWindow)(HWND);
static DpiSwitch switch_dpi;
static DpiForWindow window_dpi;
static HWND owner, window;
static HDC canvas;
static HBITMAP image, old_image;
static HFONT font, old_font;
static DWORD *pixels;
static int width,height,left,top,size_percent=90,font_percent=115,offset_x,offset_y,font_pixels;
static int test_mode,alpha=255,cursor_balance,painted;
static ATOM registered;
static HANDLE dpi_enter(void) {
    HANDLE old=0;
    if (!switch_dpi) switch_dpi=(DpiSwitch)(void *)GetProcAddress(GetModuleHandleW(L"user32.dll"),"SetThreadDpiAwarenessContext");
    if (switch_dpi) { old=switch_dpi((HANDLE)-4); if (!old) old=switch_dpi((HANDLE)-3); }
    return old;
}
static void dpi_leave(HANDLE old) { if (switch_dpi && old) switch_dpi(old); }
static int clamp(int value,int min,int max) { if (value<min) return min; return value>max ? max : value; }
static void release_surface(void) {
    if (canvas) {
        if (old_font) SelectObject(canvas,old_font);
        if (old_image) SelectObject(canvas,old_image);
        if (font) DeleteObject(font);
        if (image) DeleteObject(image);
        DeleteDC(canvas);
    }
    canvas=0; image=0; old_image=0; font=0; old_font=0; pixels=0; font_pixels=0;
}
static int surface(int w,int h) {
    BITMAPINFO info; unsigned char *raw=(unsigned char *)&info; int i;
    release_surface();
    for (i=0;i<(int)sizeof(info);i++) raw[i]=0;
    info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth=w; info.bmiHeader.biHeight=-h;
    info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32; info.bmiHeader.biCompression=BI_RGB;
    canvas=CreateCompatibleDC(0);
    if (!canvas) return 0;
    image=CreateDIBSection(canvas,&info,DIB_RGB_COLORS,(void **)&pixels,0,0);
    if (!image) { release_surface(); return 0; }
    old_image=(HBITMAP)SelectObject(canvas,image);
    SetBkMode(canvas,TRANSPARENT);
    width=w; height=h; return 1;
}
static void choose_font(void) {
    int requested=clamp((16*width*font_percent+35000)/70000,14,128);
    if (requested==font_pixels && font) return;
    if (font) { SelectObject(canvas,old_font); DeleteObject(font); }
    font=CreateFontW(-requested,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
    if (!font) return;
    old_font=(HFONT)SelectObject(canvas,font); font_pixels=requested;
}
static LRESULT CALLBACK ui_proc(HWND hwnd,UINT message,WPARAM wp,LPARAM lp) {
    if (message==WM_MOUSEACTIVATE) return MA_NOACTIVATE;
    if (message==WM_MOUSEWHEEL && owner) { SendMessageW(owner,message,wp,lp); return 0; }
    if (message==WM_SETCURSOR) { SetCursor(LoadCursorW(0,IDC_ARROW)); return TRUE; }
    return DefWindowProcW(hwnd,message,wp,lp);
}
/* Shared with tests: fixed upper footprint, smaller relative size on large clients. */
__declspec(dllexport) int __stdcall UILayout(int client_width,int client_height,int percent,int *out) {
    int base=client_width>=1000 ? client_width*68/100 : 700;
    if (client_width>=1000 && client_height>0 && base>client_height*72/100*700/400)
        base=client_height*72/100*700/400;
    base=clamp(base,client_width>=1000 ? 525 : 700,900);
    out[0]=clamp(base*clamp(percent,65,150)/100,455,1350);
    out[1]=(out[0]*400+350)/700;
    return 1;
}
__declspec(dllexport) int __stdcall UILayoutDPI(int cw,int ch,int percent,int dpi,int *out) {
    dpi=clamp(dpi,96,384);
    UILayout(cw*96/dpi,ch*96/dpi,percent,out);
    out[0]=out[0]*dpi/96; out[1]=out[1]*dpi/96;
    return 1;
}
static int position(void) {
    RECT client,work; POINT origin={0,0}; MONITORINFO monitor; int dimensions[2],x,y,resized,dpi=96;
    HMONITOR screen;
    if (test_mode) return 0;
    if (!IsWindow(owner) || !GetClientRect(owner,&client) || !ClientToScreen(owner,&origin)) return -1;
    screen=MonitorFromWindow(owner,MONITOR_DEFAULTTONEAREST);
    monitor.cbSize=sizeof(monitor);
    if (!GetMonitorInfoW(screen,&monitor)) return -1;
    work=monitor.rcWork;
    if (!window_dpi) window_dpi=(DpiForWindow)(void *)GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetDpiForWindow");
    if (window_dpi) dpi=(int)window_dpi(window);
    UILayoutDPI(client.right,client.bottom,size_percent,dpi,dimensions);
    dimensions[0]=clamp(dimensions[0],350,work.right-work.left-16);
    if (dimensions[0]>(work.bottom-work.top-16)*700/400) dimensions[0]=(work.bottom-work.top-16)*700/400;
    dimensions[1]=(dimensions[0]*400+350)/700;
    if (client.right*96/clamp(dpi,96,384)<1000) {
        /* Dock beside a small game when the desktop has room. */
        int right=origin.x+client.right+12;
        if (right+dimensions[0]<=work.right) x=right;
        else if (origin.x-12-dimensions[0]>=work.left) x=origin.x-12-dimensions[0];
        else x=(work.right-(origin.x+client.right)>=origin.x-work.left) ? work.right-dimensions[0]-8 : work.left+8;
        y=origin.y;
    } else { x=origin.x+client.right-dimensions[0]-24; y=origin.y+24; }
    x=clamp(x+offset_x,work.left+4,work.right-dimensions[0]-4);
    y=clamp(y+offset_y,work.top+4,work.bottom-dimensions[1]-4);
    resized=dimensions[0]!=width || dimensions[1]!=height;
    if (resized && !surface(dimensions[0],dimensions[1])) return -1;
    if (resized || x!=left || y!=top) {
        left=x; top=y;
        SetWindowPos(window,0,left,top,width,height,SWP_NOACTIVATE|SWP_NOZORDER);
    }
    if (GetForegroundWindow()!=owner || IsIconic(owner)) {
        if (IsWindowVisible(window)) ShowWindow(window,SW_HIDE);
    } else if (painted && !IsWindowVisible(window)) ShowWindow(window,SW_SHOWNOACTIVATE);
    return resized;
}
__declspec(dllexport) int __stdcall UIDestroy(void) {
    HANDLE old=dpi_enter();
    if (window) DestroyWindow(window);
    window=0; owner=0; release_surface();
    while (cursor_balance>0) { ShowCursor(FALSE); cursor_balance--; }
    test_mode=0; width=height=0; painted=0;
    dpi_leave(old); return 1;
}
__declspec(dllexport) int __stdcall UIOpen(HWND game,int size,int text_size) {
    HANDLE old=dpi_enter(); WNDCLASSEXW cls; unsigned char *raw=(unsigned char *)&cls; int i;
    POINT origin={0,0};
    UIDestroy(); owner=game; size_percent=clamp(size,65,150); font_percent=clamp(text_size,90,150);
    offset_x=offset_y=0;
    if (!IsWindow(owner)) { dpi_leave(old); return 0; }
    if (!registered) {
        for (i=0;i<(int)sizeof(cls);i++) raw[i]=0;
        cls.cbSize=sizeof(cls); cls.lpfnWndProc=ui_proc;
        cls.hInstance=GetModuleHandleW(0); cls.lpszClassName=L"VXCheatDisplayLayer";
        cls.hCursor=LoadCursorW(0,IDC_ARROW);
        registered=RegisterClassExW(&cls);
        if (!registered) { dpi_leave(old); return 0; }
    }
    ClientToScreen(owner,&origin);
    window=CreateWindowExW(WS_EX_LAYERED|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW,L"VXCheatDisplayLayer",L"VX Cheat Menu",
        WS_POPUP,origin.x,origin.y,1,1,owner,0,GetModuleHandleW(0),0);
    if (!window || position()<0) { UIDestroy(); dpi_leave(old); return 0; }
    do { i=ShowCursor(TRUE); cursor_balance++; } while (i<0 && cursor_balance<32);
    dpi_leave(old); return 1;
}
__declspec(dllexport) int __stdcall UIConfigure(int size,int text_size) {
    size_percent=clamp(size,65,150); font_percent=clamp(text_size,90,150); return 1;
}
__declspec(dllexport) int __stdcall UIPoll(int *out) {
    HANDLE old=dpi_enter(); POINT cursor; int result;
    result=position(); GetCursorPos(&cursor);
    out[0]=left; out[1]=top; out[2]=width; out[3]=height; out[4]=cursor.x; out[5]=cursor.y;
    out[6]=GetForegroundWindow()==owner && !IsIconic(owner);
    dpi_leave(old); return result;
}
__declspec(dllexport) int __stdcall UIMove(int dx,int dy) { offset_x+=dx; offset_y+=dy; return 1; }
__declspec(dllexport) int __stdcall UIFill(int x,int y,int w,int h,int color) {
    RECT r; HBRUSH brush;
    if (!canvas) return 0;
    r.left=x*width/700; r.top=y*height/400; r.right=(x+w)*width/700; r.bottom=(y+h)*height/400;
    brush=CreateSolidBrush((COLORREF)color); FillRect(canvas,&r,brush); DeleteObject(brush); return 1;
}
__declspec(dllexport) int __stdcall UIText(int x,int y,int w,int h,const WCHAR *text,int color,int align) {
    RECT r; UINT flags=DT_SINGLELINE|DT_VCENTER|DT_NOPREFIX|DT_END_ELLIPSIS;
    if (!canvas) return 0;
    choose_font(); SetTextColor(canvas,(COLORREF)color);
    r.left=x*width/700; r.top=y*height/400; r.right=(x+w)*width/700; r.bottom=(y+h)*height/400;
    flags|=align==1 ? DT_CENTER : align==2 ? DT_RIGHT : DT_LEFT;
    return DrawTextW(canvas,text,-1,&r,flags);
}
__declspec(dllexport) int __stdcall UIMeasure(const WCHAR *text,int length) {
    SIZE extent;
    if (!canvas || !width) return 0;
    choose_font();
    if (!GetTextExtentPoint32W(canvas,text,length,&extent)) return 0;
    return (extent.cx*700+width-1)/width;
}
static void opaque_pixels(void) {
    int i;
    GdiFlush();
    for (i=0;i<width*height;i++) pixels[i]|=0xff000000UL;
}
__declspec(dllexport) int __stdcall UIPresent(int opacity) {
    HANDLE old=dpi_enter(); POINT destination={left,top},source={0,0}; SIZE size={width,height};
    BLENDFUNCTION blend={AC_SRC_OVER,0,255,AC_SRC_ALPHA}; int result=1;
    if (!canvas) { dpi_leave(old); return 0; }
    opaque_pixels(); alpha=clamp(opacity,0,255); blend.SourceConstantAlpha=(BYTE)alpha;
    if (!test_mode) {
        result=UpdateLayeredWindow(window,0,&destination,&size,canvas,&source,0,&blend,ULW_ALPHA);
        if (result) painted=1;
        if (result && GetForegroundWindow()==owner && !IsIconic(owner) && !IsWindowVisible(window)) ShowWindow(window,SW_SHOWNOACTIVATE);
    }
    dpi_leave(old); return result;
}
/* Offscreen exports exercise the actual GDI drawing path without opening a window. */
__declspec(dllexport) int __stdcall UIOffscreen(int w,int h,int text_size) {
    UIDestroy(); test_mode=1; font_percent=clamp(text_size,90,150);
    if (w<350 || h<200 || w>2000 || h>1500) return 0;
    return surface(w,h);
}
__declspec(dllexport) int __stdcall UICopyPixels(unsigned char *buffer,int capacity) {
    unsigned char *source=(unsigned char *)pixels; int i,length=width*height*4;
    if (!canvas || capacity<length) return -1;
    opaque_pixels();
    for (i=0;i<length;i++) buffer[i]=source[i];
    return length;
}
