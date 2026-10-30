$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $bin = 'C:/msys64/mingw64/bin'
    & "$bin/dlltool.exe" -m i386 --as-flags --32 --kill-at -d user32.def -l user32-x86.a
    if ($LASTEXITCODE) { throw 'dlltool user32 failed' }
    & "$bin/dlltool.exe" -m i386 --as-flags --32 --kill-at -d kernel32.def -l kernel32-x86.a
    if ($LASTEXITCODE) { throw 'dlltool kernel32 failed' }
    & "$bin/dlltool.exe" -m i386 --as-flags --32 --kill-at -d winhttp.def -l winhttp-x86.a
    if ($LASTEXITCODE) { throw 'dlltool winhttp failed' }
    & "$bin/dlltool.exe" -m i386 --as-flags --32 --kill-at -d gdi32.def -l gdi32-x86.a
    if ($LASTEXITCODE) { throw 'dlltool gdi32 failed' }
    & "$bin/gcc.exe" -m32 -Os -Wall -Werror -fno-stack-protector -fno-builtin -nostdlib -shared input.c http.c ui.c user32-x86.a kernel32-x86.a winhttp-x86.a gdi32-x86.a '-Wl,--entry,_DllMain@12,--add-stdcall-alias' -o ../cheat/input.dll
    if ($LASTEXITCODE) { throw '32-bit DLL build failed' }
} finally { Pop-Location }
