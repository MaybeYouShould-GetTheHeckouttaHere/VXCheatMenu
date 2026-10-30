/* Headless 32-bit DLL smoke test. Does not load RGSS or the game. */
#include <windows.h>
typedef int (__stdcall *Start)(const WCHAR *,const char *,int,int);
typedef int (__stdcall *Status)(void);
typedef int (__stdcall *Read)(char *,int);
static WCHAR url[2048];
static char result[524288];
void WINAPI start(void) {
    HMODULE module; Start begin; Status status; Read read;
    WCHAR *command=GetCommandLineW();
    int i=0,post=0,state=0,length=0; DWORD written;
    if (*command==L'"') { ++command; while (*command && *command!=L'"') ++command; if (*command) ++command; }
    else { while (*command && *command!=L' ') ++command; }
    while (*command==L' ') ++command;
    while (*command && *command!=L' ' && i<2047) url[i++]=*command++;
    url[i]=0;
    while (*command==L' ') ++command;
    post=*command==L'1';
    module=LoadLibraryW(L"cheat/input.dll");
    if (!module) ExitProcess(2);
    begin=(Start)GetProcAddress(module,"TranslateStart");
    status=(Status)GetProcAddress(module,"TranslateStatus");
    read=(Read)GetProcAddress(module,"TranslateRead");
    if (!begin || !status || !read || !begin(url,"hello\nworld",11,post)) ExitProcess(3);
    for (i=0;i<1500;++i) {
        state=status();
        if (state!=1 && state!=3) break;
        Sleep(10);
    }
    if (state!=2) ExitProcess(4);
    length=read(result,sizeof(result));
    if (length<0) ExitProcess(5);
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),result,length,&written,0);
    ExitProcess(0);
}
