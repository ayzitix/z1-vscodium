#!/usr/bin/env bash
# Reproducible clean build: VSCodium + strict telemetry scrubbing + verification.
set -euo pipefail
cd "$( dirname "${BASH_SOURCE[0]}" )"

export PATH="$PWD/.toolchain/bin:$PATH"
export npm_config_python="$PWD/.toolchain/bin/python3"
# The tunnel CLI is optional; it adds a Rust build on top of the editor.
export SHOULD_BUILD_CLI="${SHOULD_BUILD_CLI:-no}"

# The previous branded build is not removed by dev/build.sh, so drop it first:
# otherwise rebrand.sh would pick the old directory.
rm -rf "${PWD}/z1-linux-x64"

./dev/build.sh
./rebrand.sh "${PWD}/VSCode-linux-x64" --install
./scrub-built-telemetry.sh
./fix-checksums.sh
./verify-clean.sh
