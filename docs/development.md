# Development

[Back to the README](../README.md)

## Modules and panel API

- `bootstrap.rb`: preserves and loads the game's original script archive.
- `ArchivePatch.cs`: encrypted-script entry installation and verified restoration.
- `storage.rb`: settings, bookmark persistence, and display-name cache.
- `input.rb`: foreground-window keyboard/mouse/clipboard polling and coordinates.
- `display.rb`: physical-pixel display-layer drawing, sizing, text, and mouse mapping.
- `core.rb`: engine hooks, actions, speed, shortcuts, and cheat flags.
- `ui.rb`: bitmap widgets, hit testing, navigation, editing, and tables.
- `translate.rb`: asynchronous translation request queue and response validation.
- `panels/*.rb`: independently registered panels, loaded alphabetically.
- `input.dll`: prebuilt 32-bit helper for mouse wheel, text, clipboard, HTTP, and
  the DPI-aware display layer. `native/ui.c` uses GDI and an owned layered window.
  Its complete source and build instructions are in `native/`.

Add a panel without changing the loader:

```ruby
VXCheat.register('Example') do |ui|
  ui.section('Party')
  ui.buttons([['Recover all', proc { $game_party.members.each { |a| a.recover_all } }]])
end
```

Panels render when the overlay is invalidated. Widgets create hit regions and callbacks;
`ui.state` stores per-panel UI state. `ui.field` edits text/numbers, `ui.checkbox`
toggles values, `ui.slider` handles ranges, and `ui.table` renders editable rows.

After changing the bootstrap, run `python build.py`. Other Ruby files load directly.
Build the helper with `native/build.ps1`; its default toolchain is MSYS2 MinGW64
GCC/binutils, using `-m32`, generated 32-bit import libraries, and no C runtime.
Run `python build_package.py` to regenerate `dist/VXAceCheatMenuImproved.zip`.

Run `python -m unittest discover -s tests` for package/installer checks. For headless
Ruby execution, install `@ruby/3.2-wasm-wasi` with npm under `.validation/ruby`, then
run `node tests/headless.cjs`. The Ruby doubles test application logic, not RGSS3.
`tests/http_probe.c` builds an optional headless 32-bit native test executable;
`tests/test_native.py` uses it against localhost. Network-isolated sandboxes need
loopback access for those three tests. Validation dependencies are not distributed.
`tests/ui_probe.c` exercises the actual GDI renderer offscreen without opening a
window or launching the game. Its tests check physical pixel output, compact and
high-DPI sizing, independent font scaling, and invalid-surface rejection.

Windows API references: [layered-window rendering](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-updatelayeredwindow)
and [per-window DPI awareness](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-improvements-for-desktop-applications).

## Display rendering

The default renderer draws a separate, DPI-aware Windows layer at physical screen
resolution. It does not enlarge the game's framebuffer, change `Graphics.width`
or `Graphics.height`, or scale an RGSS text bitmap along with the game.
At a 1920x1080 client size and 100% display scaling, the default card is 810x463.
At 200% scaling on a 3840x2160 display, it uses 1620x926 physical pixels for the same
visual size. Short clients also constrain card height. Small windowed games try to
dock the card beside the game, preserving the game view.

- **Settings -> Appearance -> UI Size** changes the footprint (default 90%).
- **Text Size** changes text separately (default 115%); it does not enlarge the card.
- **Ctrl+mouse wheel** over the native card changes its size.
- Drag the panel header to move the card. Size/text choices persist in settings.
- **Ctrl+Shift+F10** switches between the display layer and the RGSS fallback,
  including when an exclusive-fullscreen game hides the desktop layer.

Windowed or borderless display is recommended for the native layer. Exclusive
fullscreen can prevent desktop-window composition; the fallback remains available.
The native card stays above its owning game without taking keyboard focus. It
hides with an inactive/minimized game, and uses the Windows cursor. Text and card
painting still occur only on changes; cursor motion does not repaint the card.
