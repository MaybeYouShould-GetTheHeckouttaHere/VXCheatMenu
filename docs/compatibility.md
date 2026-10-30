# Compatibility and troubleshooting

[Back to the README](../README.md)

## Supported games

This package targets **RPG Maker VX Ace / RGSS3 on Windows**, including standard
encrypted `Game.rgss3a` games. It does not support RPG Maker XP, original VX,
MV, or MZ. Custom launchers, script entry points, and battle systems may require
additional compatibility work.

## Troubleshooting

### The menu does not appear

Focus the game and press Ctrl+C on a map or in battle. Check that the complete
`cheat/` folder was copied and the installer completed successfully.

Use windowed or borderless mode for the native display layer. Exclusive fullscreen
can hide desktop windows; Ctrl+Shift+F10 switches to the game-canvas fallback while
the menu is open. This shortcut also lets you return to the native renderer.

### The text is too small or the card covers too much

Open Settings > Appearance. UI Size changes the card's footprint; Text Size changes
the text independently. You can also drag the header and use Ctrl+wheel to resize.
The fallback is drawn through the game's low-resolution framebuffer, so its text
may be less sharp when the game is enlarged.

### Installation, startup, or a panel fails

Keep `Game.ini.vxcheat-backup` and the generated files in `cheat/`. Do not delete
backups to bypass a restoration or archive-change error.

Check `cheat-settings/startup-error.log` for Ruby startup failures and
`cheat-settings/ui-error.log` for panel errors, if those files were created. A panel
error should leave the sidebar available; select another panel or use Retry.

[Open an issue](https://github.com/MaybeYouShould-GetTheHeckouttaHere/VXCheatMenu/issues)
with the game title, engine version if known, the action that failed, the error
text, and relevant log contents. Review logs before sharing them. Do not upload the
game itself or its generated original-script backup.

## Behavior and limits

The overlay pauses the map or battle while open and preserves its existing scene.
Native save/load screens use the game's own controls. Teleporting and saving are
restricted to the map; loading is also available from battle.

God mode restores HP/MP/TP on battler refresh and skips skill costs. Custom death
scripts or direct field writes can bypass those hooks. Inventory quantities and
actor parameters remain constrained by engine or game-specific caps.

Game speed changes rendering waits. Audio, video, and custom timing code may not
follow it. The native UI uses Windows rendering rather than Vue/Vuetify, so fonts,
icons, tooltips, and text-selection gestures differ from the MV/MZ menus.

Headless checks cover application logic, persistence, archive installation and
restoration, native HTTP, and offscreen drawing. They do not establish compatibility
with every game's custom scripts or replace in-game testing.

## Detailed feature reference

- **General:** no clip, gold, movement speed 1-10 in 0.5 steps, Fixed speed,
  game speed 0.1-10 in 0.1 steps with All/Battle scope, and title/save/load actions.
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
  recall/delete actions. Locations can be recalled or deleted from the panel.
- **Teleport:** X/Y fields, searchable map names/ancestry, Hide Full Path, and
  transfer actions. Map bounds are validated before transfer.
- **Translate:** ezTransWeb, eztrans-server, and custom GET/POST endpoints using
  the source plugin's `${TEXT}` placeholder, configurable chunks and target
  maps/switches/variables, a server availability test, and cached display names.
