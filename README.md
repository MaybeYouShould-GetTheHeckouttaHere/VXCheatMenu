# VX Ace Cheat Menu Improved

Version **0.3.0**. A modular Windows RGSS3 port of the supplied MV/MZ cheat menus,
with mouse controls and a compact dark overlay drawn at desktop resolution.
Its 700Ã—400 logical layout uses the source menu's 200px sidebar, panel names, inline fields,
sliders, searchable tables, five-row pagination, and hover opacity.

Targets **RPG Maker VX Ace / RGSS3**, including encrypted `Game.rgss3a` games.
Original RPG Maker VX / RGSS2 is not supported.

## Install or update

1. Close the game. Copy `cheat/`, `Install.ps1`, `Install.cmd`, and `Uninstall.cmd`
   beside `Game.exe` and `Game.ini`.
2. Double-click `Install.cmd` once. No Ruby, Python, browser, or compiler is needed.
3. Launch normally. Press **Ctrl+C** on a map or in battle.

For an existing installation, merge the new `cheat/` files and installer files,
then run `Install.cmd`. Preserve the generated `cheat/original_path.rb`,
`cheat/original_scripts.rvdata2`, and `cheat/archive-backup.bin` where present.
F6 is no longer the default; use Ctrl+C.

The installer backs up `Game.ini` to `Game.ini.vxcheat-backup` and records its original
Scripts path. For loose games it redirects that path to `cheat/bootstrap.rvdata2`.
For encrypted games, RGSS3 ignores loose script bundles: the installer instead
appends the bootstrap to `Game.rgss3a` and redirects its existing Scripts index
entry. Existing encrypted asset bytes and offsets stay unchanged. The original
script bundle is preserved as `cheat/original_scripts.rvdata2`; its index record,
archive size, and original-content SHA-256 are journaled in `cheat/archive-backup.bin`.
The bootstrap evaluates the original scripts in order and loads the cheat modules
immediately before the last script containing `SceneManager.run`. Save files are
not replaced. Nonstandard launchers or Main scripts may require an adapter.

`Uninstall.cmd` restores the original INI and encrypted archive byte for byte.
Keep all installation backups while installed. Archive restoration first checks
the original-content hash and refuses to overwrite unrelated archive changes.
Uninstalling leaves cheat settings and bookmarks intact; it does not
undo changes saved to game progress. For a different target folder, copy the
payload there and use `Install.ps1 -GameDirectory 'path'`. Do not transfer the
generated `cheat/original_path.rb` between games.

## Default controls

These bindings match the supplied MV and MZ menus:

| Keys | Action |
|---|---|
| Ctrl+C | Toggle cheat overlay |
| Ctrl+M | Toggle Save Locations panel |
| Ctrl+S / Ctrl+Q | Quick save / quick load, slot 1 by default |
| Ctrl+[ / Ctrl+] | Open native save / load screen |
| Ctrl+T | Return to title |
| Ctrl+V / Ctrl+D / Ctrl+E | Force victory / defeat / escape |
| Alt+W | Toggle no clip |
| Alt+1 / Alt+0 | Enemies: HP to 1 / recovery |
| Alt+2 / Alt+9 | Party: HP to 1 / recovery |
| Unbound | Set movement speed; hold to skip messages |

**F12 retains RGSS3's engine-reset behavior.** Chromium developer tools have no
native equivalent and that action is not remappable here.

Use the mouse to select panels, collapse Items/Settings groups, toggle checkboxes,
drag sliders, edit table cells, turn pages, and recall locations. The wheel scrolls
the panel under the cursor. Page Up/Down also scroll. Right-click or Esc closes
the overlay when a field is not being edited.

Fields select their existing text when focused. Type to replace, use arrow keys
or Home/End to move the caret, Backspace/Delete to edit, Ctrl+A to select all,
and Ctrl+C/X/V to copy/cut/paste. Enter or clicking another control applies; Esc
cancels. Tab/Shift+Tab move between visible fields. Enter in Location Alias adds
the bookmark. Shortcut capture supports combinations and rejects duplicate
bindings; Backspace clears an optional binding and Esc cancels capture.

## Sharp text and compact size

The default renderer draws a separate, DPI-aware Windows layer at physical screen
resolution. It does not enlarge the game's framebuffer, change `Graphics.width`
or `Graphics.height`, or scale an RGSS text bitmap along with the game.
At a 1920Ã—1080 client size and 100% display scaling, the default card is 810Ã—463.
At 200% scaling on a 3840Ã—2160 display, it uses 1620Ã—926 physical pixels for the same
visual size. Short clients also constrain card height. Small windowed games try to
dock the card beside the game, preserving the game view.

- **Settings â†’ Appearance â†’ UI Size** changes the footprint (default 90%).
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

## Functionality

- **General:** no clip, gold, movement speed 1â€“10 in 0.5 steps, Fixed speed,
  game speed 0.1â€“10 in 0.1 steps with All/Battle scope, and title/save/load actions.
- **Shortcuts:** editable bindings, restore defaults, quick-save/load slot
  parameters, speed parameter, and held message-skip acceleration.
- **HP/MP/Battle:** random encounter suppression, force encounter/victory/defeat/
  escape/abort, enemy and party HP 0/1/recovery/TP-fill actions, and HP/MP fields.
- **Stats/Level:** actor tabs, per-actor god mode, level/EXP, and all eight parameters.
- **Items:** Item/Weapon/Armor tables, search, Hide Nameless/Only Owned filters,
  descriptions, and editable quantities constrained by the game's inventory cap.
- **Clear States:** clear party/enemy states or remove individual party states.
- **Variables/Switches:** search, Hide Nameless filters, inline edits, and bulk
  toggle of filtered switches. Integers, floats, strings, and booleans retain their
  types; custom objects are displayed without being overwritten.
- **Save Locations:** named, persistent map/coordinate/direction bookmarks with
  recall/delete actions. This now matches the MV/MZ location feature; the earlier
  in-memory save snapshot has been removed.
- **Teleport:** X/Y fields, searchable map names/ancestry, Hide Full Path, and
  transfer actions. Map bounds are validated before transfer.
- **Translate:** ezTransWeb, eztrans-server, and custom GET/POST endpoints using
  the source plugin's `${TEXT}` placeholder, configurable chunks and target
  maps/switches/variables, a server availability test, and cached display names.

## Persistent cheat data

The game root's **`cheat-settings/`** directory contains:

| File | Contents |
|---|---|
| `settings.ini` | No clip, encounter suppression, god-mode actor IDs, speeds, shortcuts, translation settings |
| `locations.tsv` | Bookmarks; names are UTF-8 bytes encoded as hex for safe round trips |
| `translations.tsv` | UTF-8 display-name overrides and translation cache |
| `startup-error.log` | Ruby startup exception details, when a bootstrap error occurs |
| `ui-error.log` | Isolated panel/action exceptions with backtraces |

Settings are written when changed, using a temporary file and Windows atomic
replacement. If writing fails, the overlay reports it and changes continue for
the session. Cheat flags live in the cheat module and these sidecar files; they
are not added to game saves. They apply across save slots in the same game folder.
Actual changes to gold, items, variables, actor stats, etc. remain ordinary game
state and can be saved normally.

Translation is disabled by default. Start the selected translation server, enable
translation, choose targets, and click **Translate names**. Requests run on a
native worker thread with timeouts; gameplay/Ruby never waits for the HTTP server.
Responses may be plain UTF-8 text or a JSON string, with one line per input name.
GET batches are reduced to fit URL limits. HTTP failures and malformed responses
retain existing names. Custom requests are limited to 2,047 UTF-16 URL characters,
131,071 body bytes, and 524,287 response bytes. No server is installed or launched.

Manual display-name overrides use `category<TAB>id<TAB>name` in
`translations.tsv`. Categories: `item`, `weapon`, `armor`, `actor`, `map`, `switch`,
`variable`. Click Reload translations after editing the file.

## Engine differences and testing

This is a native Ruby/Windows UI with the same menu structure and controls, not a
Vue/Vuetify renderer. Fonts, icons, browser tooltips, arbitrary text-selection
gestures, and browser layout details are not pixel-identical. The overlay pauses
the map/battle while open and preserves the existing scene, including battle state.
Native save/load screens use their game's own controls.

Version 0.2.2 fixed the VX Ace `Game_Actor#id` API used by Stats/Level and god mode.
It introduced invalidation, cached RGSS text, a separate fallback cursor sprite,
and batched keyboard polling. Version 0.3.0 adds the display-resolution renderer
without removing those optimizations. Panel exceptions show a recoverable error
view and keep the sidebar available.

Game-speed control adjusts rendering waits rather than `Graphics.frame_rate` or
dispatching repeated key events. Audio/video and custom timing code may behave
differently. God mode keeps HP/MP/TP full on battler refresh and skips skill costs;
custom death scripts or direct instance-variable writes can bypass engine hooks.
Battle/encounter actions assume the usual VX Ace APIs. Teleporting and saving are
restricted to the map; loading is available from battle as well.

**No in-game testing has been performed; the user is handling it.** Validation
includes Ruby syntax parsing, headless Ruby execution against RGSS API doubles,
filesystem persistence/Unicode bookmarks, UI/panel rendering and editing logic,
installer/restore checks, and a real 32-bit DLL HTTP test against a temporary local
server. These checks do not establish compatibility with a game's custom scripts
or verify actual RGSS rendering, mouse alignment, or gameplay behavior.

## Modules and development

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
