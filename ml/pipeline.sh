#!/usr/bin/env bash
# Unattended stage runner on rbm21. Waits for the ES-walk validation to end,
# then launches the 3D ES lateral-balance attempt (teacher = walker_slow.json).
# ONE heavy job at a time, niced. Started detached (setsid) so it survives ssh
# close. Progress: pipeline.log + STATUS.json (2D) + STATUS3.json (3D).
cd "$HOME/machin-walker" || exit 1
LOG=pipeline.log
say() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG"; }

say "pipeline up; waiting for es_walk_probe to finish"
while pgrep -x es_walk_probe >/dev/null 2>&1; do sleep 60; done
say "es_walk_probe ended: $(grep -hoE 'ES WALK GATE PASSED|es walk gate not passed' esw.log 2>/dev/null | tail -1)"

if pgrep -x es_walk3_train >/dev/null 2>&1; then
  say "es_walk3_train already running; abort"; exit 0
fi
if [ ! -x ./es_walk3_train ]; then
  say "es_walk3_train binary missing; abort"; exit 1
fi

rm -f ml/models/walker3_h.json ml/models/walker3.json ml/models/walker3_try.json STATUS3.json
say "launching es_walk3_train (3D ES, teacher=walker_slow.json)"
nice -n 12 ./es_walk3_train > train3d_es.log 2>&1
say "es_walk3_train ended: $(grep -hoE '3D GATE PASSED|3D gate not passed' train3d_es.log 2>/dev/null | tail -1)"
say "pipeline done"
