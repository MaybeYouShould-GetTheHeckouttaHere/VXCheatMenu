/* Asynchronous, bounded plain-text translation client. No Ruby calls on worker. */
#include <windows.h>
#include <winhttp.h>
static volatile LONG status;
static WCHAR request_url[2048], host[256], route[4096], extra[2048];
static char request_body[131072], response[524288];
static DWORD body_length, response_length;
static int post_request;
static DWORD WINAPI translate_worker(LPVOID unused) {
    URL_COMPONENTS parts;
    HINTERNET session=0, connection=0, request=0;
    DWORD available=0, received=0, code=0, code_size=sizeof(DWORD);
    int i, path_length, ok=0;
    unsigned char *p=(unsigned char *)&parts;
    for (i=0;i<(int)sizeof(parts);++i) p[i]=0;
    parts.dwStructSize=sizeof(parts);
    parts.lpszHostName=host; parts.dwHostNameLength=255;
    parts.lpszUrlPath=route; parts.dwUrlPathLength=2047;
    parts.lpszExtraInfo=extra; parts.dwExtraInfoLength=2047;
    response_length=0;
    if (!WinHttpCrackUrl(request_url,0,0,&parts)) goto done;
    if (parts.nScheme!=INTERNET_SCHEME_HTTP && parts.nScheme!=INTERNET_SCHEME_HTTPS) goto done;
    path_length=(int)parts.dwUrlPathLength;
    for (i=0;i<(int)parts.dwExtraInfoLength && path_length<4094;++i) route[path_length++]=extra[i];
    if (!path_length) route[path_length++]=L'/';
    route[path_length]=0;
    session=WinHttpOpen(L"VXCheat/0.2",WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,0,0,0);
    if (!session) goto done;
    WinHttpSetTimeouts(session,3000,3000,5000,10000);
    connection=WinHttpConnect(session,host,parts.nPort,0);
    if (!connection) goto done;
    request=WinHttpOpenRequest(connection,post_request ? L"POST" : L"GET",route,0,0,0,
        parts.nScheme==INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0);
    if (!request) goto done;
    if (!WinHttpSendRequest(request,L"Content-Type: text/plain; charset=utf-8\r\n",(DWORD)-1L,
            post_request ? request_body : 0,post_request ? body_length : 0,post_request ? body_length : 0,0)) goto done;
    if (!WinHttpReceiveResponse(request,0)) goto done;
    if (!WinHttpQueryHeaders(request,WINHTTP_QUERY_STATUS_CODE|WINHTTP_QUERY_FLAG_NUMBER,0,&code,&code_size,0)) goto done;
    if (code<200 || code>=300) goto done;
    for (;;) {
        if (!WinHttpQueryDataAvailable(request,&available)) goto done;
        if (!available) break;
        if (response_length+available>=sizeof(response)) goto done;
        if (!WinHttpReadData(request,response+response_length,available,&received)) goto done;
        if (!received) break;
        response_length+=received;
    }
    ok=1;
done:
    if (request) WinHttpCloseHandle(request);
    if (connection) WinHttpCloseHandle(connection);
    if (session) WinHttpCloseHandle(session);
    InterlockedExchange(&status,ok ? 2 : -1);
    return 0;
}
__declspec(dllexport) int __stdcall TranslateStart(const WCHAR *url,const char *body,int bytes,int post) {
    HANDLE thread; int i;
    if (InterlockedCompareExchange(&status,3,0)!=0) return 0;
    if (bytes<0 || bytes>=(int)sizeof(request_body)) { InterlockedExchange(&status,0); return 0; }
    for (i=0;url[i] && i<2047;++i) request_url[i]=url[i];
    request_url[i]=0;
    if (url[i]) { InterlockedExchange(&status,0); return 0; }
    for (i=0;i<bytes;++i) request_body[i]=body[i];
    body_length=bytes; post_request=post;
    InterlockedExchange(&status,1);
    thread=CreateThread(0,0,translate_worker,0,0,0);
    if (!thread) { InterlockedExchange(&status,0); return 0; }
    CloseHandle(thread); return 1;
}
__declspec(dllexport) int __stdcall TranslateStatus(void) { return (int)InterlockedCompareExchange(&status,0,0); }
__declspec(dllexport) int __stdcall TranslateRead(char *buffer,int capacity) {
    int i, length;
    if (InterlockedCompareExchange(&status,0,0)!=2 || capacity<(int)response_length) return -1;
    length=(int)response_length;
    for (i=0;i<length;++i) buffer[i]=response[i];
    InterlockedExchange(&status,0); return length;
}
__declspec(dllexport) int __stdcall TranslateReset(void) {
    LONG current=InterlockedCompareExchange(&status,0,0);
    if (current==1 || current==3) return 0;
    InterlockedExchange(&status,0); return 1;
}
