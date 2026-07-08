#!/usr/bin/env bash
# Build the walker viewer. Vendors static raylib if no system one.
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
MODS="src/pbd3.src src/body3.src src/walk3_task.src ml/vendor/tinybrain.src game/walker3_game.src"
if pkg-config --exists raylib 2>/dev/null || [ -f /usr/include/raylib.h ]; then
    "$MACHIN" encode $MODS > walker3.mfl
else
    RL="raylib-5.0_linux_amd64"; D="vendor/$RL"
    if [ ! -f "$D/lib/libraylib.a" ]; then
        mkdir -p vendor
        if [ -d "/tmp/rl/$RL" ]; then cp -r "/tmp/rl/$RL" vendor/
        else curl -fsSL "https://github.com/raysan5/raylib/releases/download/5.0/$RL.tar.gz" | tar xz -C vendor; fi
    fi
    INC="$PWD/$D/include"; LIB="$PWD/$D/lib"
    "$MACHIN" encode $MODS | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" > walker3.mfl
fi
"$MACHIN" build walker3.mfl -o walker3-game
rm -f walker3.mfl
echo "built ./walker3-game — run from the repo root (loads ml/models/walker.json)"
