#!/usr/bin/env bash
# Headless tests: the physics contract, then the walk gate on the committed artifact.
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
cat src/pbd.src tests/pbd_test.src | "$MACHIN" encode /dev/stdin > /tmp/walker_t1.mfl
"$MACHIN" run /tmp/walker_t1.mfl
cat src/pbd.src src/body.src src/walk_task.src ml/vendor/tinybrain.src tests/walk_test.src | "$MACHIN" encode /dev/stdin > /tmp/walker_t2.mfl
"$MACHIN" run /tmp/walker_t2.mfl
cat src/pbd3.src tests/pbd3_test.src | "$MACHIN" encode /dev/stdin > /tmp/walker_t3.mfl
"$MACHIN" run /tmp/walker_t3.mfl
