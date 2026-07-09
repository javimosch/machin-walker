# machin-walker

**A human-shaped biped that *learned to walk — and to run*.** A [tinybrain](https://github.com/javimosch/tinybrain) neural network (13 sensors → 16 → 4, one ~4.7 KB JSON artifact) drives six torque-limited joints — *and its own gait clock* — of a 1.75 m / 70 kg humanoid through a rigorous pure-[machin](https://github.com/javimosch/machin) physics simulation. Two certified artifacts, one controller architecture: a strict **walk** (`walker_slow.json`, 0.62 Hz — 12.5 m at ~0.54 m/s, 44 % double-support, under 8 % airborne) and a **run** (`walker.json`, 0.95 Hz — 12.5 m at 1.3–1.5 m/s, flight-phase). Both: **zero falls on every noise seed never seen in training**, human-flexing knees, counter-swinging arms.

**[▶ watch it run in your browser](https://javimosch.github.io/machin-walker/)** — the physics runs in wasm; JS only draws.

This is the "how machin could make robots walk" demo: everything a real robot controller is allowed — and nothing it isn't.

## Walk vs. run — how cadence decided everything

At 0.95 Hz, evolution found a **run** and no fitness shape could suppress the flight (cliffs pinned populations at identical salvage scores; bounded slopes flattened at their floor; the walk basin was unreachable from the run basin by small mutations). The strict walk fell almost immediately once the *cadence* changed: at **0.62 Hz** the same pipeline — CPG prior, clone, harness curriculum, gated rounds — produced a grounded walking gait in its very first curriculum level and passed the strict gate (<8 % flight, ≥10 m, zero falls, 5 held-out seeds, reloaded artifact) in two gate rounds. The lesson generalizes: when evolution keeps finding the "wrong" gait, the fitness isn't wrong — the *tempo* is.

**Full 3D lateral balance remains open, with the boundary honestly mapped**: at running speed it exceeded this net size + GA budget (the twist problem was solved along the way — see the `pbd3` bearing-alignment constraint — but the final gate champions degenerated into standing statues). The slow walker above is the designated teacher for the next 3D attempt: wide stability margins at 0.54 m/s are exactly what lateral learning needs.

## The physics contract (enforced by tests)

`src/pbd.src` (planar) and `src/pbd3.src` (3D, for the lateral-balance milestone) are XPBD-style articulated-body simulations whose rules are *tested*, not promised:

- **Internal actuation only.** Joint motors are textbook PBD angular-constraint projections — torque-limited, momentum-conserving by construction (`grad_b = -(grad_a+grad_c)`). Airborne flailing moves the COM by 1e-13 m. No world-frame springs, no balance assist, no velocity caps.
- **Coulomb friction**: kinetic slide distance matches `v²/2μg` to three digits; the 3D core has a true tangential friction cone (diagonal slides preserve direction).
- Inverse-mass constraints, substeps, joint limits (knees flex only the human way — a sign bug here once produced a very convincing *backwards* walker).
- Motor authority calibrated to ~11 rad/s hip; 5× that produced a physics-exploit dive-sprint, caught and fixed.

Dynamics are **planar (sagittal)** — Walker2D-standard — rendered as a 3D skeleton. The full-3D rig (widened pelvis, tripod feet, frontal hip/ankle motors) is built, contract-tested, and staged in `src/*3.src` + `ml/walk3_train.src`.

## The controller

One net is the whole controller, run once per leg per tick at phase φ and φ+π (mirror symmetry). Inputs: gait phase, torso pitch **and pitch rate**, hip height, forward **and vertical** velocity, 4 joint angles, 2 foot contacts — ±1–1.5 % sensor noise always on in training. Outputs: hip/knee/ankle servo targets **plus a clock-rate modulation** (learned step timing — capture-point stepping is what made self-balance possible; without it every curriculum stalled at the assist→zero cliff). Arms counter-swing through weak torque-limited shoulder servos — real masses, part of the trained dynamics.

## How it was trained (the honest arc)

Every failure mode was diagnosed, fixed, and left in the history:

1. **Superhuman torques** → 3.3 m/s dive-sprint exploit → calibrated motor caps.
2. **Distance-only fitness** → hopping → flight/crouch shaping.
3. **Noise-free training** → champions overfit to exact weight bits (chaotic contact dynamics) → sensor noise, robust scoring.
4. **Plain GA crawled** → tinybrain doctrine: CPG expert → SGD clone → `warm_start` evolve.
5. **No derivative senses** → posture limit-cycles → pitch-rate + vertical-velocity inputs (the same lesson the arm reacher taught).
6. **Fixed evaluation seeds get memorized** — repeatedly → fresh seeds per round; gates only on the reloaded artifact.
7. **Fixed gait clock** → can't step early to catch a fall → the learned clock-rate output; assist-free locomotion appeared within one curriculum of adding it.
8. **Uncapped distance credit** bred a 40 m leaper → credit caps at 12 m; nothing beyond the goal pays.
9. **A memory leak in paradise**: machin goroutine arenas are reclaimed only on return — persistent parallel-evolve workers exhausted 10 GB over a multi-hour run → fixed upstream in tinybrain (arena-wrapped exchange + periodic worker respawn).

Training runs on a 14-core box via tinybrain's parallel evolution (`cfg.workers`, bit-identical to sequential, race-inference-verified) — a feature this project drove upstream, twice.

## Run it

```sh
./tests/run_tests.sh    # physics contracts (2D: 10, 3D: 7) + the locomotion gate on the committed artifact (9)
./build.sh && ./walker-game    # watch it: 3D skeleton, tracking camera, HUD
./web/build.sh                 # rebuild docs/ (the GitHub Pages demo)
```

`ml/walk_train5.src` retrains end-to-end on a many-core box; `ml/walk3_train.src` is the staged 3D lateral-balance pipeline (distills this artifact as its teacher).

## Certified numbers (committed artifacts)

**Walk** (`ml/models/walker_slow.json`, 0.62 Hz):
- 8/8 probe seeds (5 gate + 3 extra): all 12.5 m, **zero falls**, flight 5.9–8.2 %, ~0.54 m/s.
- Gait shape: 51 % single-support / **44 % double-support** / 6 % flight — definitionally walking.

**Run** (`ml/models/walker.json`, 0.95 Hz):
- Noise-free: 12.5 m at 1.46 m/s, upright, zero falls; 5 gate seeds: min 12.51 m, zero falls.
- Gait: flight 42–53 % — honest running.

## Open milestones

- **Lateral balance** (full 3D) — physics, rig, trainer and landing kit all staged; the boundary at running speed is mapped, and the slow walker is the designated teacher for the next attempt.
