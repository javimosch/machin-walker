#!/usr/bin/env bash
# Self-serve training status: one ssh, no persistent monitor. Shows the
# pipeline log + both stage STATUS files + what's running.
ssh rbm21 'cd ~/machin-walker 2>/dev/null || exit
echo "=== pipeline.log (last 6) ==="; tail -6 pipeline.log 2>/dev/null || echo "(no pipeline yet)"
echo; echo "=== STATUS.json  — stage 1: 2D ES walk validation ==="; cat STATUS.json 2>/dev/null || echo "(none)"
echo; echo "=== STATUS3.json — stage 2: 3D ES lateral balance ==="; cat STATUS3.json 2>/dev/null || echo "(not started)"
echo; echo "=== running ==="; pgrep -xl "es_walk_probe|es_walk3_train|pipeline.sh" 2>/dev/null || echo "(nothing training)"' 2>/dev/null
