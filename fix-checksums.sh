#!/usr/bin/env bash
# Recompute the integrity checksums in product.json after the tree was modified
# by rebrand.sh / scrub-built-telemetry.sh. Without this VS Code shows
# "Your installation appears to be corrupt. Please reinstall."
#
# usage: ./fix-checksums.sh [app-dir]
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP="${1:-}"
if [[ -z "${APP}" ]]; then
  for d in "${ROOT}/z1-linux-x64" "${ROOT}/VSCode-linux-x64"; do
    if [[ -d "${d}/resources/app" ]]; then APP="${d}"; break; fi
  done
fi
[[ -n "${APP}" && -d "${APP}/resources/app" ]] || { echo "app dir not found" >&2; exit 1; }

python3 - "${APP}/resources/app" <<'PY'
import base64, hashlib, json, os, sys

res = sys.argv[1]
path = os.path.join(res, 'product.json')

with open(path, encoding='utf-8') as f:
    product = json.load(f)

checksums = product.get('checksums') or {}
for rel in list(checksums):
    full = os.path.join(res, 'out', rel)
    if not os.path.exists(full):
        print(f'  missing, skipped: {rel}')
        continue
    with open(full, 'rb') as f:
        digest = hashlib.sha256(f.read()).digest()
    checksums[rel] = base64.b64encode(digest).decode('ascii').rstrip('=')
    print(f'  {rel}')

keys = os.path.join(res, 'out', 'nls.keys.json')
messages = os.path.join(res, 'out', 'nls.messages.json')
if os.path.exists(keys) and os.path.exists(messages):
    h = hashlib.sha256()
    h.update((product.get('commit') or '').encode())
    h.update(b'\0')
    h.update(open(keys, 'rb').read())
    h.update(b'\0')
    h.update(open(messages, 'rb').read())
    product['nlsMetadataHash'] = h.hexdigest()
    print(f'  nlsMetadataHash -> {product["nlsMetadataHash"]}')

with open(path, 'w', encoding='utf-8') as f:
    json.dump(product, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY

echo "checksums updated: ${APP}/resources/app/product.json"
