---
name: 3d-lateral-balance
description: >-
  Resume the machin-walker 3D lateral-balance investigation (making the humanoid
  balance sideways while walking, not just in the sagittal plane). Read BEFORE
  touching any src/*3.src, ml/sag3*, ml/testb, ml/lat_spike, ml/cadence_sweep, or
  training the 3D rig on rbm21. Captures the honest state (PAUSED — mapped, not
  solved), everything already PROVEN, every dead-end already tried (don't repeat
  them), two hard-won infra gotchas (arena + chaos-sensitivity), the precisely
  located wall, the ranked next levers, and the rbm21 operating protocol.
---

# machin-walker — 3D lateral balance

## Status: PAUSED — the wall is mapped, not cracked (2026-07-10)

- **DELIVERED & LIVE:** 2D sagittal **walk** (0.62 Hz, <8% flight) + **run**, both
  certified, shipped, v1.0.0, live wasm (`javimosch.github.io/machin-walker`).
- **OPEN FRONTIER:** 3D lateral (frontal-plane) balance — walk in true 3D.
- All 3D work is on branch **`3d-lateral-balance-wip`** (not merged to main).
- rbm21 is idle/clean; leftover training binaries were removed.

## The goal & the reframe

Make the biped hold **frontal-plane (lateral) balance while walking**, so it walks
in 3D rather than only the sagittal plane. The framing that reorganized the
problem: **DECOUPLE the planes.** Sagittal balance (forward gait + step *timing*)
and frontal balance (lateral foot *placement* / step width) are largely separable
control channels in real bipeds. All four *earlier* attempts (before this arc)
failed because they learned the coupled sagittal+frontal problem at once via
black-box search.

## What is PROVEN (rely on these)

1. **Lateral authority EXISTS** — `ml/lat_spike.src` (analytic frontal push-recovery):
   a CoM PD → antisymmetric hip ab/adduction + ankle inversion, plus a torso-roll
   PD on the spine, centers the CoM **3–5× better than passive** under a shove.
   The old GA "can't get lateral authority / stuck at 0.32 assist" wall was a
   **black-box-search artifact, not a physics limit.** The lateral controller was
   never the blocker.
2. **0.40 Hz is the 3D walk cadence** — `ml/cadence_sweep.src`: the heavier 3D rig
   (widened pelvis + tripod feet) wants a **slower** step than 2D's 0.62 Hz. Sweep:
   0.35→17%, **0.40→~8% flight (the walk seed)**, 0.45→39%, 0.50→14%, 0.55–0.70 all
   bounce. Cadence is the analog of the lever that unlocked the 2D strict walk.

## What FAILED — do NOT repeat

1. **2D→3D transfer** (`ml/testb.src`): driving the 3D sagittal joints with the
   frozen certified 2D walker (`walker_slow.json`, exact 13-input/4-output bridge)
   walks **BACKWARD (−2 to −6 m) and sags — in all four sagittal sign conventions.**
   The 3D masses differ too much for the closed-loop 2D policy. Transfer is dead.
2. **Native plain GA from random** (`ml/sag3_train.src`, v1): descends + goes
   forward, but **plateaus at a bounding lunge** (fitness ~3.18).
3. **CPG-clone + warm-start — the 2D recipe** (`ml/sag3_train2.src`, v2), even at
   **0.40 Hz with the real ~8%-flight seed:** **STILL bounces** — champion 7.6 m,
   68% flight, falls; fitness plateaus at **3.16** (the same bounce ceiling as the
   0.62 Hz run). Cadence alone does NOT crack it.
4. **Hardcoded printed seed** (`ml/sag3_train3.src`): ABANDONED — see gotcha #2.

## Two hard-won infrastructure gotchas

1. **Arena / main-goroutine loops.** Building a `biped3` per iteration in a
   main-goroutine loop WITHOUT `arena{}` accumulates (allocations aren't reclaimed
   until fn-return) → the CPG search built 2300 rigs → **swap-thrashed rbm21**
   (host load 55, sshd wedged). FIX: `arena{}`-wrap every per-episode eval. And to
   return the best params, **track them in scalars and ELEMENT-WRITE into a
   caller-pre-allocated slice** — `s3_cpg_search(samples, refines, maxTicks, out)`.
   Reassigning a `best = []float{...}` slice near `arena{}` returns **stale/corrupt
   values** (printed params didn't reproduce). Peak RSS after the fix: 72 MB.
2. **Chaos-sensitivity (the big one).** The 3D contact dynamics are **chaotically
   sensitive to the last bits.** A seed's printed 12-digit params evaluate to a
   TOTALLY different gait (in-memory best = 8% flight / survives 900 ticks; the same
   params printed→hardcoded = 30% flight / falls at tick 114). This is the
   documented "overfit to weight bits" phenomenon. **CONSEQUENCE: a seed must stay
   IN-MEMORY through search → clone → evolve. NEVER round-trip params through text.**
   That is why `sag3_train2.src` (in-memory) is correct and `sag3_train3.src`
   (hardcoded printed seed) is wrong.

## The wall, precisely located

NOT lateral authority. NOT lateral-controller design. NOT cadence. The wall is:
**getting a stable native 3D sagittal WALK**, blocked by
- **(a) clone-divergence** — the SGD clone is trained with *random* sensor values,
  so it IGNORES feedback; its closed-loop rollout drifts backward and falls even
  from the 8% seed (MSE is perfect ~4e-5, but open-loop-map ≠ closed-loop-stable).
- **(b) the bounce basin** — with the clone diverged, evolve maximizes
  distance-under-the-flight-cliff by leaping (ceiling ≈ 0.25 × 12.5 m ≈ 3.14), and
  the walk basin is unreachable from there by local mutation.

## Next levers (ranked — pick ONE, deliberately)

1. **Sensor-aware cloning (highest leverage).** Clone from ACTUAL rollout
   trajectories (real sensor values along a stabilized/railed CPG run), not random
   sensors — so the net learns to USE feedback and doesn't diverge closed-loop.
   Attacks root cause (a). Swap only the dataset-generation step in `sag3_train2`.
2. **Skip the clone.** Direct gated-convergence evolve at 0.40 Hz with HARD
   hop-suppression (REJECT any >8%-flight episode, don't just penalize) + fresh
   seeds per round + gate on a reloaded champion (mirror 2D `walk_train4`).
3. **Explicit ground-contact-time reward** in `s3_ep_score` (reward foot-down
   fraction, not just penalize flight).
4. **Then Stage B** (only after a real sagittal walk stands): anneal the rail off
   while the analytic lateral capture-point controller (proven authority) + a small
   learned residual takes over. `src/body3.src` already has the frontal motors,
   tripod feet, and the twist stabilizer (bearing-alignment) staged.

## Files (branch `3d-lateral-balance-wip`)

- `src/pbd3.src`, `src/body3.src` — the 3D rig: PBD physics, widened pelvis, tripod
  feet, frontal hip/ankle motors, bearing-alignment twist stabilizer. Sensors:
  `biped3_pitch/roll/yaw`, `w3_com`, `biped3_fallen`.
- `src/sag3.src` — shared 3D-sagittal machinery: 13-input sensor vector (matches 2D
  `body.src` units), `s3_apply`, `s3_rail` (frontal-plane rail), CPG expert
  (`cpg_hip/knee/ank`), arena-safe `s3_cpg_search(...,out)`, episodes, `s3_fitness`.
  Cadence is a global: `g_s3_hz` (default 0.62; set 0.40 for 3D).
- `ml/lat_spike.src` — lateral push-recovery spike (proves authority).
- `ml/testb.src` — the 2D→3D bridge (proves transfer fails).
- `ml/sag3_train.src` (v1 plain GA), `ml/sag3_train2.src` (v2 clone+warmstart @0.40).
- `ml/cadence_sweep.src` — the cadence sweep.
- `ml/sag3_train3.src` (ABANDONED, hardcoded seed), `ml/diag.src` (chaos diagnostic).
- `ml/models/sag3*.json` + `*.jsonl` — the (bouncing) champions + training logs.
- `ml/vendor/{tinybrain,evolve}.src` — vendored tinybrain (net + evolve_run + SGD).

Build any trainer:
`machin encode src/pbd3.src src/body3.src ml/vendor/tinybrain.src ml/vendor/evolve.src src/sag3.src ml/<trainer>.src > /tmp/t.mfl && machin build /tmp/t.mfl -o <bin>`

## rbm21 operating protocol (the training box) — BE GENTLE

- 14-core LXC (**CT 201** on host **pve2**); SHARED PROD box (services: `am-cloud`,
  `mago`, `hermes`, `machin-vault`). Do not starve them.
- Caps: **≤8–10 workers**, `nice -n 12`, ONE heavy job at a time, arena-wrap every
  main-loop episode build. It only had ~5–6 GB free — pop 96 fits, pop 128 thrashed.
- Detach: `setsid nohup nice -12 ./bin > log 2>&1 < /dev/null &`. Non-blocking:
  read the first 1–2 rounds, report ETA, stop; a re-check is one `ssh` of the jsonl.
- If sshd wedges (banner timeout), monitor via `ssh pve2 'pct exec 201 -- ...'`.
- If it thrashes (host load ≫ 14, `pct exec` hangs): recover with
  `ssh pve2 'pct stop 201'` → wait for load to settle → `pct start 201` (all
  services auto-restart). This is user-authorized.
- **Clean up after:** `rm` the compiled binary from `~/ai/machin-walker/` when done
  (leftover binaries read as "still using resources").

## How to resume

Pick lever #1 (sensor-aware cloning). The rig, the pipeline, the arena-safety, and
the 0.40 Hz cadence are all solid and memory-safe — swap only the clone's dataset
to real rollout sensors, re-run `sag3_train2`-style on rbm21 under the caps above,
and check whether the champion's flight drops below 8% while distance grows. If a
real sagittal walk stands, move to Stage B (lateral capture-point + residual).
