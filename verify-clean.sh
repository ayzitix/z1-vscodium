#!/usr/bin/env bash
# Verify that the built app is branded "z1", free of Microsoft telemetry
# endpoints and has valid integrity checksums.
#
# usage: ./verify-clean.sh [repo-root]
set -uo pipefail

ROOT="${1:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )}"
APP=""
for d in "${ROOT}/z1-linux-x64" "${ROOT}/VSCode-linux-x64"; do
  if [[ -d "${d}/resources/app" ]]; then APP="${d}"; break; fi
done
PRODUCT="${APP}/resources/app/product.json"
SRC="${ROOT}/vscode"
BRAND="${ROOT}/branding"

pass=0
fail=0
ok()   { printf '  OK   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '  ..   %s\n' "$1"; }

echo "== product.json =="
if [[ -n "${APP}" && -f "${PRODUCT}" ]]; then
  jq -e '.nameShort == "z1" and .nameLong == "z1"' "${PRODUCT}" >/dev/null \
    && ok 'name = z1' || bad 'name is not z1'
  jq -e '.applicationName == "z1"' "${PRODUCT}" >/dev/null \
    && ok 'applicationName = z1' || bad 'applicationName is not z1'
  jq -e '.linuxIconName == "z1"' "${PRODUCT}" >/dev/null \
    && ok 'linuxIconName = z1' || bad 'linuxIconName is not z1'
  jq -e '.extensionsGallery.serviceUrl | test("open-vsx\\.org")' "${PRODUCT}" >/dev/null \
    && ok 'extensions gallery = Open VSX' || bad 'extensions gallery is not Open VSX'
  if jq -e '.updateUrl // empty' "${PRODUCT}" >/dev/null 2>&1; then
    jq -e '.updateUrl | test("microsoft|visualstudio") | not' "${PRODUCT}" >/dev/null \
      && ok 'updateUrl does not point at Microsoft' || bad 'updateUrl points at Microsoft'
  else
    ok 'no updateUrl (update service disabled)'
  fi
  jq -e 'has("aiKey") | not' "${PRODUCT}" >/dev/null && ok 'no aiKey' || note 'aiKey present'
else
  bad "missing ${PRODUCT} (build not finished?)"
fi

echo "== branding =="
ICON="${APP}/resources/app/resources/linux/code.png"
if [[ -f "${ICON}" && -f "${BRAND}/z1.png" ]]; then
  a=$( sha256sum "${ICON}" | cut -d' ' -f1 )
  b=$( sha256sum "${BRAND}/z1.png" | cut -d' ' -f1 )
  [[ "${a}" == "${b}" ]] && ok 'window/app icon = z1' || bad 'icon is not the z1 logo'
else
  bad 'missing z1 icon'
fi
[[ -x "${APP}/bin/z1" ]] && ok "launcher: ${APP}/bin/z1" || bad 'missing bin/z1 launcher'
[[ -f "${HOME}/.local/share/applications/z1.desktop" ]] \
  && ok 'desktop entry installed (z1.desktop)' || note 'desktop entry not installed'
if [[ -f "${APP}/resources/app/out/media/letterpress-dark.svg" ]]; then
  grep -q 'z1' "${APP}/resources/app/out/media/letterpress-dark.svg" \
    && ok 'empty-editor watermark assets = z1' || note 'watermark assets have no title'
fi
if grep -q 'z1-watermark-rotate' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.css"; then
  ok 'animated watermark CSS present (body rotation)'
else
  bad 'animated watermark CSS is missing'
fi
if grep -q 'z1-watermark' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.js"; then
  ok 'watermark eye-tracking script present'
else
  bad 'watermark eye-tracking script is missing'
fi
if grep -q 'z1: strict 90-degree corners' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.css"; then
  ok 'strict 90-degree UI corners (border-radius: 0)'
else
  bad 'square UI CSS is missing'
fi
if grep -q 'z1: hide empty-editor shortcut hints' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.css"; then
  ok 'empty-editor shortcut hints hidden'
else
  bad 'empty-editor shortcut hints are still visible'
fi
if grep -q 'z1-welcome-page' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.css" \
   && grep -q 'z1-welcome-card' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.js"; then
  ok 'Cursor-style z1 welcome screen present'
else
  bad 'z1 welcome screen is missing'
fi
if cmp -s "${BRAND}/z1-mark-white.svg" "${APP}/resources/app/out/vs/workbench/browser/media/code-icon.svg"; then
  ok 'title bar / tab mark = z1'
else
  bad 'title bar / tab mark is not the z1 logo'
fi

echo "== theme =="
THEME_DIR="${APP}/resources/app/extensions/theme-defaults"
for t in "z1 Dark" "z1 Default" "z1 Soft"; do
  file="$( jq -r --arg id "${t}" '.contributes.themes[] | select(.id == $id) | .path' "${THEME_DIR}/package.json" 2>/dev/null )"
  if [[ -n "${file}" && -f "${THEME_DIR}/${file#./}" ]]; then
    jq -e . "${THEME_DIR}/${file#./}" >/dev/null \
      && ok "${t} theme JSON is valid" || bad "${t} theme JSON is invalid"
  else
    bad "${t} is not registered/installed"
  fi
done
jq -e '.colors["button.background"] == "#FFFFFF" and .colors["textLink.foreground"] == "#FFFFFF"' \
  "${THEME_DIR}/themes/z1-default.json" >/dev/null \
  && ok 'z1 Default accent is white' || bad 'z1 Default accent is not white'
jq -e '.colors["titleBar.border"] == "#2A2A2A" and .colors["panel.border"] == "#2A2A2A" and .colors["editorGroup.border"] == "#2A2A2A"' \
  "${THEME_DIR}/themes/z1-default.json" >/dev/null \
  && ok 'visible panel/window frames (#2A2A2A)' || bad 'panel/window frames are transparent'
grep -q 'COLOR_THEME_DARK="z1 Default"' "${APP}/resources/app/out/vs/workbench/workbench.desktop.main.js" \
  && ok 'z1 Default is the built-in default dark theme' || bad 'default dark theme is not z1 Default'
if [[ -f "${HOME}/.config/z1/User/settings.json" ]] \
   && jq -e '."workbench.colorTheme" == "z1 Default"' "${HOME}/.config/z1/User/settings.json" >/dev/null 2>&1; then
  ok 'z1 Default selected in user settings'
else
  note 'z1 Default not selected in user settings'
fi
if grep -rIl -E 'Cursor Dark|cursor-dark|cursor-less-dark|CedricVerlinden' \
     "${THEME_DIR}" "${HOME}/.z1/extensions" 2>/dev/null | grep -q .; then
  bad 'Cursor brand strings remain'
else
  ok 'no Cursor brand strings in themes/user extensions'
fi

echo "== telemetry defaults (source) =="
TEL_SRC="${SRC}/src/vs/platform/telemetry/common/telemetryService.ts"
if [[ -f "${TEL_SRC}" ]]; then
  grep -q "'default': TelemetryConfiguration.OFF" "${TEL_SRC}" \
    && ok 'telemetry.telemetryLevel defaults to off' || bad 'telemetry.telemetryLevel not off'
else
  note "source not found: ${TEL_SRC}"
fi

echo "== Microsoft telemetry hosts in shipped code =="
if [[ -n "${APP}" ]]; then
  hits=$( { grep -rIl --exclude-dir=node_modules -E '//[A-Za-z0-9._-]+\.(data\.microsoft\.com|services\.visualstudio\.com)' "${APP}" 2>/dev/null || true; } | wc -l)
  if [[ "${hits}" -eq 0 ]]; then
    ok 'no Microsoft telemetry ingestion hosts in the built app'
  else
    bad "${hits} file(s) still reference Microsoft telemetry hosts"
    grep -rIl --exclude-dir=node_modules -E '//[A-Za-z0-9._-]+\.(data\.microsoft\.com|services\.visualstudio\.com)' "${APP}" 2>/dev/null | head -10 | sed 's/^/       /'
  fi
else
  bad "missing app dir (build not finished?)"
fi

echo "== integrity checksums =="
if [[ -n "${APP}" && -f "${PRODUCT}" ]]; then
  python3 - "${APP}/resources/app" <<'PY'
import base64, hashlib, json, os, sys
res = sys.argv[1]
product = json.load(open(os.path.join(res, 'product.json')))
bad = 0
for rel, stored in (product.get('checksums') or {}).items():
    full = os.path.join(res, 'out', rel)
    if not os.path.exists(full):
        bad += 1
        continue
    actual = base64.b64encode(hashlib.sha256(open(full, 'rb').read()).digest()).decode().rstrip('=')
    if actual != stored:
        print(f'       mismatch: {rel}')
        bad += 1
print('  OK   product.json checksums match' if bad == 0 else f'  FAIL {bad} checksum mismatch(es)')
sys.exit(1 if bad else 0)
PY
  [[ $? -eq 0 ]] && pass=$((pass + 1)) || fail=$((fail + 1))
fi

echo "== runtime =="
if [[ -x "${APP}/bin/z1" ]]; then
  "${APP}/bin/z1" --version 2>/dev/null | sed 's/^/       /'
else
  note "launcher not found: ${APP}/bin/z1"
fi

echo
echo "passed: ${pass}  failed: ${fail}"
exit $(( fail > 0 ? 1 : 0 ))
