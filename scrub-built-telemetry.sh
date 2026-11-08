#!/usr/bin/env bash
# Blackhole Microsoft telemetry ingestion hosts inside an already-built app tree.
# Mirrors undo_telemetry.sh, but works on the packaged app (compiled bundles +
# built-in extensions) instead of the VS Code source tree.
#
# usage: ./scrub-built-telemetry.sh [app-dir]
set -euo pipefail

TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  for d in "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/z1-linux-x64" \
           "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/VSCode-linux-x64"; do
    [[ -d "${d}" ]] && { TARGET="${d}"; break; }
  done
fi
[[ -d "${TARGET}" ]] || { echo "no such directory: ${TARGET}" >&2; exit 1; }

PATTERN='//[A-Za-z0-9._-]+\.(data\.microsoft\.com|services\.visualstudio\.com)'
REPLACEMENT='//0.0.0.0'

echo "scrubbing ${TARGET}"
mapfile -d '' files < <(grep -rIlZ -E "${PATTERN}" "${TARGET}" 2>/dev/null || true)

echo "files to scrub: ${#files[@]}"
for f in "${files[@]}"; do
  sed -i -E "s#${PATTERN}#${REPLACEMENT}#g" "${f}"
done

left=$( { grep -rIl -E "${PATTERN}" "${TARGET}" 2>/dev/null || true; } | wc -l )
echo "remaining references: ${left}"
[[ "${left}" -eq 0 ]]
