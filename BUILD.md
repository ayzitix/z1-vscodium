# z1 build

Portable editor built from VSCodium (VS Code) sources, rebranded to **z1**,
with Microsoft telemetry and Microsoft online services removed/disabled.

## Versions

| thing | value |
|---|---|
| VSCodium repo | `VSCodium/vscodium` @ `ca7f7b4` |
| VS Code source | `microsoft/vscode` @ `e6468682` (tag `1.143.1`) |
| built version | `1.143.17502` |
| Electron/Node used | Node `24.18.0` (local, `.toolchain/node`, from `.nvmrc`) |
| Python for native modules | `3.11.16` (via `uv`) |

## Where things are

| path | what |
|---|---|
| `z1-linux-x64/` | the built, runnable editor |
| `z1-linux-x64/bin/z1` | launcher |
| `z1-linux-x64/z1.desktop` | desktop entry (also installed to `~/.local/share/applications/z1.desktop`) |
| `branding/` | z1 mark: `z1.svg` (white blob with two eyes, transparent), PNG sizes, `.ico`, watermark template, `z1-default.json` / `z1-soft.json` / `z1-dark.json` themes |
| `vscode/` | VS Code source tree with VSCodium patches applied |
| `.toolchain/` | local Node 24.18.0 + python3 shim (not system-wide) |

Run it:

```bash
./z1-linux-x64/bin/z1
# or open a folder:
./z1-linux-x64/bin/z1 /path/to/project
```

## Branding

Everything user-visible is `z1`:

- product metadata (`nameShort`, `nameLong`, `applicationName`, `linuxIconName`,
  `urlProtocol`, server/tunnel names, `.desktop` name)
- window title and application id (`z1`, so the taskbar/launcher matches
  `z1.desktop`)
- executable and launcher names (`z1`, `bin/z1`)
- data directory (`~/.config/z1`)
- welcome page: `z1`, `Get started with z1`, `z1 Announcements`
- Cursor-style Welcome screen: z1 brand line and a 2×2 card grid
  (Open project, Clone repo, Connect via SSH, About z1)
- Activity Bar is fixed to **top**; the position switcher (menu, command
  palette and setting) is removed
- empty-editor watermark: the z1 body slowly rotates (32s), the eyes follow
  the mouse cursor (inline SVG, `z1Watermark.ts`),
  rendered at 128px
- app/window icon is the z1 mark (white blob with two dark eyes)
- title bar and Welcome tab mark is the z1 mark (white, `code-icon.svg`)
- default theme **z1 Default**: Cursor Dark palette with all blue accents
  replaced by white (buttons/links/badges `#FFFFFF`), no Cursor mentions;
  selected in `~/.config/z1/User/settings.json` and used as the built-in
  default dark theme
- **z1 Soft** — lighter variant of the same palette
- **z1 Dark** — alternative neutral dark theme with lime/pink accents

### Themes

| id | file | notes |
|---|---|---|
| `z1 Default` | `branding/z1-default.json` | default; `#1a1a1a` editor, white accents |
| `z1 Soft` | `branding/z1-soft.json` | lighter background |
| `z1 Dark` | `branding/z1-dark.json` | lime `#c8f56a` + pink `#ff6fa5` |

The themes are copied into `extensions/theme-defaults/themes/` by
`rebrand.sh` and registered there. `COLOR_THEME_DARK` is patched to
`z1 Default`, so it is the default for new profiles.

To iterate: edit the JSON under `branding/`, run `./rebrand.sh --install`,
clear `~/.config/z1/CachedProfilesData/*/extensions.*.cache` if the theme list
is cached, and reload.
- UI strings in core and built-in extensions (`"VSCodium"` → `"z1"`), while
  keeping working URLs (`github.com/VSCodium/...`, Open VSX, update feed)
- VSCodium's remote announcements feed is disabled by default, so no
  "Securing VSCodium" items appear
- integrity checksums are recomputed after rebranding, so the
  "installation appears to be corrupt" warning does not appear

## What was removed/disabled

1. **VSCodium patches** (`patches/`, applied by `prepare_vscode.sh`):
   - `telemetry.telemetryLevel` default `off`
   - `telemetry.enableCrashReporter` default `false`
   - experiments / natural-language settings search default `false`
   - `undo_telemetry.sh` rewrites `*.data.microsoft.com` hosts to `0.0.0.0`
   - Microsoft Marketplace replaced with Open VSX
   - update URL points at VSCodium's version feed, not Microsoft
   - Copilot / Microsoft cloud features removed
   - Microsoft branding replaced

2. **Extra hardening added in this build**
   - `undo_telemetry.sh` also blackholes `*.services.visualstudio.com`
     (Application Insights ingestion used by `@vscode/extension-telemetry`).
   - `patches/user/00-telemetry-strict.patch`:
     - `telemetryUtils.getTelemetryLevel()` falls back to `OFF`
     - Agent Host: `telemetryLevel` = `off`, `editTelemetryEnabled` = `false`,
       `disableRepoInfoTelemetry` = `true`
   - `scrub-built-telemetry.sh`: post-packaging pass over the *built* app,
     because gulp re-bundles some built-in extensions after `undo_telemetry.sh`.
   - `rebrand.sh`: product name, icons, watermarks, binary/launcher names and
     remaining UI strings.
   - `fix-checksums.sh`: recomputes `product.json.checksums` (base64, no padding)
     and `nlsMetadataHash` after every modification.
   - `verify-clean.sh`: asserts branding, telemetry defaults, absence of
     Microsoft telemetry hosts and checksum integrity.

## Verification

```bash
./verify-clean.sh
```

Current result: `passed: 27 failed: 0`, including:

- `name = z1`, `applicationName = z1`, `linuxIconName = z1`
- Open VSX gallery, no Microsoft update URL, no `aiKey`
- window/app icon matches `branding/z1.png`
- title bar / tab mark matches `branding/z1-mark-white.svg`
- animated watermark CSS (body rotation) and eye-tracking script are present
- strict 90-degree UI corners (`border-radius: 0`)
- empty-editor shortcut hints are hidden
- Cursor-style z1 welcome screen is present
- Activity Bar position switching removed
- `z1 Default`, `z1 Soft`, `z1 Dark` are valid and registered
- `z1 Default` has white accents and is the built-in default dark theme
- no Cursor brand strings in the themes or user extensions
- no `*.data.microsoft.com` / `*.services.visualstudio.com` hosts
- all `product.json` checksums match
- compiled defaults: workbench telemetry `"off"`, crash reporter `false`,
  agent host telemetry `off`

## Rebuilding

Full clean rebuild (deletes `vscode/` and the old `z1-linux-x64/`, re-clones
VS Code, ~25 min on 8 cores):

```bash
./build-clean.sh
```

Incremental rebuild after editing `vscode/` sources (~3 min):

```bash
cd vscode
export PATH="$( dirname "$PWD" )/.toolchain/bin:$PATH"
export NODE_OPTIONS=--max-old-space-size=8192
npm run gulp vscode-linux-x64-min-packing
cd ..
./rebrand.sh VSCode-linux-x64 --install
./scrub-built-telemetry.sh
./fix-checksums.sh
./verify-clean.sh
```

## Notes / limits

- This is VSCodium (VS Code with patches), rebranded as z1.
- The built-in Microsoft authentication provider (`login.microsoftonline.com`)
  still works and is only contacted if you explicitly sign in with a Microsoft
  account.
- Some extension code still contains the literal `0.0.0.0` placeholder where a
  telemetry endpoint used to be; that is the intended blackhole.
- Individual third-party extensions can still send their own telemetry.
- `SHOULD_BUILD_CLI=no` was used, so the optional Rust tunnel CLI is not built.
- `dev/build.sh` also produces `vscode-reh-linux-x64/` and
  `vscode-reh-web-linux-x64/` (remote server / web server artifacts). Those are
  not used by the desktop app and still carry the upstream VSCodium name.
