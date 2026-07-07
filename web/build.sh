#!/usr/bin/env bash
# Build the browser demo into docs/ (GitHub Pages). Needs zig for C->wasm.
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
[ -f ml/models/walker.json ] || { echo "ml/models/walker.json missing" >&2; exit 1; }
mkdir -p docs
cat src/pbd.src src/body.src src/walk_task.src ml/vendor/tinybrain.src web/walker_wasm.src | "$MACHIN" encode /dev/stdin > /tmp/walker_wasm.mfl
"$MACHIN" build /tmp/walker_wasm.mfl --target wasm -o docs/walker.wasm
cp web/index.html docs/index.html
cp ml/models/walker.json docs/walker.json
ls -la docs/
echo "built docs/ — serve locally: python3 -m http.server -d docs 8332"
