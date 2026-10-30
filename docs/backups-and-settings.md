# Backups, updates, and saved settings

[Back to the README](../README.md)

## Installation backups

Keep these files in their original game folder:

| File | Purpose |
|---|---|
| `Game.ini.vxcheat-backup` | Original game configuration |
| `cheat/original_path.rb` | Game-specific script path |
| `cheat/original_scripts.rvdata2` | Original script bundle, for encrypted games |
| `cheat/archive-backup.bin` | Reversal record for encrypted archive changes |

Some files apply only to encrypted games. Do not copy generated backups from one
game into another.

## Updates and uninstalling

Close the game before installing, updating, or uninstalling. To update, merge the
new `cheat/` files and installer files into the game folder, preserving generated
backups, then run `Install.cmd` again.

`Uninstall.cmd` restores the original INI and, where applicable, the encrypted
archive. Archive restoration checks that unrelated content has not changed and
refuses to overwrite unexpected changes. Keep the error message if restoration
fails; do not delete the backup journal to work around it.

Uninstalling leaves cheat settings and bookmarks in place. Changes saved to game
progress, such as added items or edited stats, are not undone.

## Saved cheat settings

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

## Translation and display-name overrides

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

## What the installer changes

The original `Game.ini` is backed up first. For loose games, its Scripts entry is
redirected to `cheat/bootstrap.rvdata2`.

For encrypted games, RGSS3 ignores loose script bundles. The installer appends the
bootstrap to `Game.rgss3a` and redirects the existing Scripts index entry to it.
Existing encrypted asset data and offsets remain unchanged. The original script
bundle, index record, archive size, and content hash are preserved for restoration.

The bootstrap evaluates the original scripts in order and loads the menu before
Main. Nonstandard launchers or script entry points may need an adapter. Installation
does not replace save files.
