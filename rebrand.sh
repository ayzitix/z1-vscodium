#!/usr/bin/env bash
# Rebrand a built VSCodium tree to "z1": product metadata, icons, watermarks,
# binary/launcher names and remaining "VSCodium" UI strings.
#
# usage: ./rebrand.sh [app-dir] [--install]
#   --install  also add ~/.local/share/applications/z1.desktop and the icon
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BRAND="${ROOT}/branding"
NAME="z1"

INSTALL="no"
APP=""
for arg in "$@"; do
  case "${arg}" in
    --install) INSTALL="yes" ;;
    *) APP="${arg}" ;;
  esac
done

if [[ -z "${APP}" ]]; then
  for d in "${ROOT}/${NAME}-linux-x64" "${ROOT}/VSCode-linux-x64"; do
    if [[ -d "${d}/resources/app" ]]; then APP="${d}"; break; fi
  done
fi
if [[ -z "${APP}" || ! -d "${APP}/resources/app" ]]; then
  echo "no built app found (expected ${NAME}-linux-x64/ or VSCode-linux-x64/)" >&2
  exit 1
fi

RES="${APP}/resources/app"
echo "rebranding ${APP} -> ${NAME}"

# ---------------------------------------------------------------- product.json
tmp="$( mktemp )"
jq --arg n "${NAME}" '
  .nameShort = $n
  | .nameLong = $n
  | .applicationName = $n
  | .dataFolderName = ("." + $n)
  | .linuxIconName = $n
  | .urlProtocol = $n
  | .serverApplicationName = ($n + "-server")
  | .serverDataFolderName = ("." + $n + "-server")
  | .tunnelApplicationName = ($n + "-tunnel")
  | .win32DirName = $n
  | .win32NameVersion = $n
  | .win32RegValueName = $n
  | .win32ShellNameShort = $n
  | .win32AppUserModelId = ($n + "." + $n)
  | .win32MutexName = $n
  | .win32TunnelMutex = ($n + "-tunnel")
  | .win32TunnelServiceMutex = ($n + "-tunnelservice")
  | .darwinBundleIdentifier = ("com." + $n)
' "${RES}/product.json" > "${tmp}"
mv "${tmp}" "${RES}/product.json"

# ---------------------------------------------------------------- package.json
jq --arg n "${NAME}" '.name = $n | .author = { name: $n } | .desktopName = ($n + ".desktop")' "${RES}/package.json" > "${tmp}"
mv "${tmp}" "${RES}/package.json"

# ---------------------------------------------------------------- server manifest
if [[ -f "${RES}/resources/server/manifest.json" ]]; then
  jq --arg n "${NAME}" '.name = $n | .short_name = $n' "${RES}/resources/server/manifest.json" > "${tmp}"
  mv "${tmp}" "${RES}/resources/server/manifest.json"
fi

# ---------------------------------------------------------------- icons
install -m 644 "${BRAND}/z1.png" "${RES}/resources/linux/code.png"
install -m 644 "${BRAND}/z1.svg" "${RES}/resources/linux/code.svg"

# title bar + welcome tab mark (white z1 blades)
install -m 644 "${BRAND}/z1-mark-white.svg" "${RES}/out/vs/workbench/browser/media/code-icon.svg"
install -m 644 "${BRAND}/z1-mark-white.svg" "${RES}/out/media/code-icon.svg"

# slightly larger app mark in the title bar (16px -> 20px)
CSS_MAIN="${RES}/out/vs/workbench/workbench.desktop.main.css"
if [[ -f "${CSS_MAIN}" ]]; then
  perl -0pi -e 's/(\.window-appicon:not\(\.codicon\)\{[^}]*?background-size:)16px/${1}20px/' "${CSS_MAIN}"
  # smaller empty-editor watermark (256px -> 128px)
  perl -0pi -e 's/(\.editor-group-watermark \.letterpress\{[^}]*?max-width:)256px/${1}128px/' "${CSS_MAIN}"
fi

# strict 90-degree corners everywhere (no rounded UI)
append_square_ui() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  grep -q 'z1: strict 90-degree corners' "${f}" && return 0
  cat >> "${f}" <<'CSS'

/* z1: strict 90-degree corners */
:root, .monaco-workbench {
  --vscode-cornerRadius-circle: 0px;
  --vscode-cornerRadius-xLarge: 0px;
  --vscode-cornerRadius-large: 0px;
  --vscode-cornerRadius-medium: 0px;
  --vscode-cornerRadius-small: 0px;
  --vscode-cornerRadius-xSmall: 0px;
  --vscode-cornerRadius-xxSmall: 0px;
}
*, *::before, *::after {
  border-radius: 0 !important;
}
CSS
}
append_square_ui "${RES}/out/vs/workbench/workbench.desktop.main.css"
append_square_ui "${RES}/out/vs/sessions/sessions.desktop.main.css"

# z1 colour themes inside the built-in theme-defaults extension
THEME_DIR="${RES}/extensions/theme-defaults"
if [[ -d "${THEME_DIR}" ]]; then
  for t in z1-dark z1-default z1-soft; do
    install -m 644 "${BRAND}/${t}.json" "${THEME_DIR}/themes/${t}.json"
  done
  theme_tmp="$( mktemp )"
  jq '
    .contributes.themes = (
      ((.contributes.themes // []) | map(select(.id as $i | ["z1 Dark", "z1 Default", "z1 Soft"] | index($i) | not)))
      + [
        { "id": "z1 Dark",    "label": "z1 Dark",    "uiTheme": "vs-dark", "path": "./themes/z1-dark.json" },
        { "id": "z1 Default", "label": "z1 Default", "uiTheme": "vs-dark", "path": "./themes/z1-default.json" },
        { "id": "z1 Soft",    "label": "z1 Soft",    "uiTheme": "vs-dark", "path": "./themes/z1-soft.json" }
      ]
    )
  ' "${THEME_DIR}/package.json" > "${theme_tmp}"
  mv "${theme_tmp}" "${THEME_DIR}/package.json"
fi

# ---------------------------------------------------------------- watermarks
make_mark() { # file size fill opacity eye
  sed -e "s/@W@/$2/g" -e "s/@FILL@/$3/g" -e "s/@OP@/$4/g" -e "s/@EYE@/$5/g" "${BRAND}/letterpress.svg.in" > "$1"
}
while IFS= read -r -d '' f; do
  base="$( basename "${f}" )"
  size=40
  [[ "${base}" == *sessions* ]] && size=128
  case "${base}" in
    *[Ll]ight*) make_mark "${f}" "${size}" "#101012" "0.20" "#FFFFFF" ;;
    *)          make_mark "${f}" "${size}" "#FFFFFF" "0.28" "#101012" ;;
  esac
done < <( find "${RES}/out" -type f -name 'letterpress-*.svg' -print0 )

# ---------------------------------------------------------------- UI strings
# Replace standalone "VSCodium" in every text file that carries it, but keep
# working URLs such as github.com/VSCodium/... and
# raw.githubusercontent.com/VSCodium/...
while IFS= read -r -d '' f; do
  perl -0pi -e 's{(?<![/])VSCodium(?![/])}{z1}g' "${f}"
done < <( grep -rIlZ --exclude='*.map' \
            --exclude='LICENSE.txt' --exclude='ThirdPartyNotices.txt' \
            --exclude='LICENSES.chromium.html' \
            -e 'VSCodium' "${RES}" 2>/dev/null || true )

# lower-case product identifiers baked into the bundles/fallbacks
while IFS= read -r -d '' f; do
  perl -0pi -e '
    s/applicationName:"codium"/applicationName:"z1"/g;
    s/desktopName:"codium\.desktop"/desktopName:"z1.desktop"/g;
    s/dataFolderName:"\.vscode-oss-shared"/dataFolderName:".z1-shared"/g;
    s/dataFolderName:"\.vscode-oss"/dataFolderName:".z1"/g;
    s/linuxIconName:"vscodium"/linuxIconName:"z1"/g;
    s/urlProtocol:"vscodium"/urlProtocol:"z1"/g;
    s/serverApplicationName:"codium-server"/serverApplicationName:"z1-server"/g;
    s/serverDataFolderName:"\.vscodium-server"/serverDataFolderName:".z1-server"/g;
    s/tunnelApplicationName:"codium-tunnel"/tunnelApplicationName:"z1-tunnel"/g;
    s/win32MutexName:"vscodium"/win32MutexName:"z1"/g;
    s/win32TunnelMutex:"vscodium-tunnel"/win32TunnelMutex:"z1-tunnel"/g;
    s/win32TunnelServiceMutex:"vscodium-tunnelservice"/win32TunnelServiceMutex:"z1-tunnelservice"/g;
    s/darwinBundleIdentifier:"com\.vscodium"/darwinBundleIdentifier:"com.z1"/g;
  ' "${f}"
done < <( grep -rIlZ --exclude='*.map' -e 'codium' -e 'vscodium' "${RES}/out" 2>/dev/null || true )

# VSCodium's welcome page fetches announcements from its GitHub repo at runtime
# ("Securing VSCodium", ...). Disable that feed by default.
WB_MAIN="${RES}/out/vs/workbench/workbench.desktop.main.js"
if [[ -f "${WB_MAIN}" ]]; then
  perl -0pi -e 's/("workbench\.welcomePage\.extraAnnouncements":\{[^}]{0,80}?)default:!0/${1}default:!1/' "${WB_MAIN}"
  # make the z1 theme the default dark theme
  perl -0pi -e 's/(COLOR_THEME_DARK=")Dark 2026(")/${1}z1 Default${2}/' "${WB_MAIN}"
fi

# ---------------------------------------------------------------- binary names
[[ -f "${APP}/codium" && ! -e "${APP}/z1" ]] && mv "${APP}/codium" "${APP}/z1"
[[ -f "${APP}/bin/codium" && ! -e "${APP}/bin/z1" ]] && mv "${APP}/bin/codium" "${APP}/bin/z1"

if [[ -f "${APP}/bin/${NAME}" ]]; then
  perl -0pi -e 's/\bcodium\b/z1/g; s{(?<![/])VSCodium(?![/])}{z1}g' "${APP}/bin/${NAME}"
  chmod +x "${APP}/bin/${NAME}"
fi
[[ -f "${APP}/${NAME}" ]] && chmod +x "${APP}/${NAME}"

# ---------------------------------------------------------------- folder name
if [[ "$( basename "${APP}" )" != "${NAME}-linux-x64" ]]; then
  mv "${APP}" "${ROOT}/${NAME}-linux-x64"
  APP="${ROOT}/${NAME}-linux-x64"
fi

# ---------------------------------------------------------------- desktop entry
cat > "${APP}/${NAME}.desktop" <<EOF
[Desktop Entry]
Name=${NAME}
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=${APP}/bin/${NAME} %F
Icon=${BRAND}/z1.png
Type=Application
StartupNotify=false
StartupWMClass=${NAME}
Categories=TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
Actions=new-empty-window;
Keywords=${NAME};vscode;codium;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${APP}/bin/${NAME} --new-window %F
Icon=${BRAND}/z1.png
EOF

if [[ "${INSTALL}" == "yes" ]]; then
  mkdir -p "${HOME}/.local/share/applications"
  mkdir -p "${HOME}/.local/share/icons/hicolor/512x512/apps"
  install -m 644 "${APP}/${NAME}.desktop" "${HOME}/.local/share/applications/${NAME}.desktop"
  install -m 644 "${BRAND}/z1.png" "${HOME}/.local/share/icons/hicolor/512x512/apps/${NAME}.png"
  command -v update-desktop-database >/dev/null && update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  echo "installed desktop entry: ${HOME}/.local/share/applications/${NAME}.desktop"
fi

echo "done: ${APP}/bin/${NAME}"

# Built-in extension manifests are cached per profile; drop the cache so the
# newly registered z1 themes and icons are picked up on the next start.
CFG="${XDG_CONFIG_HOME:-${HOME}/.config}/z1"
rm -f "${CFG}/CachedProfilesData/"*/extensions.*.cache 2>/dev/null || true
