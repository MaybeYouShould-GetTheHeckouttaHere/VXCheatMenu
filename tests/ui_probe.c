/* Actual 32-bit GDI renderer, offscreen only. Binary drawing protocol on stdin. */
#include <windows.h>
typedef int (__stdcall *Offscreen)(int,int,int);
typedef int (__stdcall *Fill)(int,int,int,int,int);
typedef int (__stdcall *Text)(int,int,int,int,const WCHAR *,int,int);
typedef int (__stdcall *Copy)(unsigned char *,int);
typedef int (__stdcall *Layout)(int,int,int,int,int *);
typedef int (__stdcall *Destroy)(void);
static unsigned char pixels[12000000];
static WCHAR label[8192];
static void read_exact(void *target,int length) {
    unsigned char *bytes=(unsigned char *)target; DWORD received;
    while (length>0) {
        if (!ReadFile(GetStdHandle(STD_INPUT_HANDLE),bytes,length,&received,0) || received==0) ExitProcess(40);
        length-=(int)received; bytes+=received;
    }
}
void WINAPI start(void) {
    HMODULE module=LoadLibraryW(L"cheat/input.dll");
    Offscreen open; Fill fill; Text text; Copy copy; Layout layout; Destroy destroy;
    int header[4],record[8],out[2],i,length; DWORD written;
    if (!module) ExitProcess(2);
    open=(Offscreen)GetProcAddress(module,"UIOffscreen");
    fill=(Fill)GetProcAddress(module,"UIFill");
    text=(Text)GetProcAddress(module,"UIText");
    copy=(Copy)GetProcAddress(module,"UICopyPixels");
    layout=(Layout)GetProcAddress(module,"UILayoutDPI");
    destroy=(Destroy)GetProcAddress(module,"UIDestroy");
    if (!open || !fill || !text || !copy || !layout || !destroy) ExitProcess(3);
    layout(1920,1080,90,96,out); if (out[0]!=810 || out[1]!=463) ExitProcess(10);
    layout(3840,2160,90,192,out); if (out[0]!=1620 || out[1]!=926) ExitProcess(11);
    layout(1280,720,90,96,out); if (out[0]>=1280*75/100 || out[1]>=720*75/100) ExitProcess(12);
    layout(1920,480,90,96,out); if (out[1]>=480*75/100) ExitProcess(13);
    read_exact(header,sizeof(header));
    if (!open(header[0],header[1],header[2]) || header[3]<0 || header[3]>5000) ExitProcess(4);
    for (i=0;i<header[3];i++) {
        read_exact(record,sizeof(record));
        if (record[7]<0 || record[7]>8191) ExitProcess(5);
        if (record[0]==1) fill(record[1],record[2],record[3],record[4],record[5]);
        else {
            read_exact(label,record[7]*2); label[record[7]]=0;
            text(record[1],record[2],record[3],record[4],label,record[5],record[6]);
        }
    }
    length=copy(pixels,sizeof(pixels));
    if (length<0) ExitProcess(6);
    destroy();
    if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),pixels,length,&written,0) || written!=(DWORD)length) ExitProcess(7);
    ExitProcess(0);
}
