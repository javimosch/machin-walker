# machin-walker

**A human-shaped biped that *learned* to run.** A [tinybrain](https://github.com/javimosch/tinybrain) neural network (13 sensors → 16 → 4, one ~4.7 KB JSON artifact) drives six torque-limited joints — *and its own gait clock* — of a 1.75 m / 70 kg humanoid through a rigorous pure-[machin](https://github.com/javimosch/machin) physics simulation. The certified artifact covers **12.5 m at 1.3–1.5 m/s with zero falls on every noise seed never seen in training**, in a natural flight-phase running gait with human-flexing knees and counter-swinging arms.

**[▶ watch it run in your browser](https://javimosch.github.io/machin-walker/)** — the physics runs in wasm; JS only draws.

This is the "how machin could make robots walk" demo: everything a real robot controller is allowed — and nothing it isn't.

## Run vs. walk — the honest framing

The challenge was "walk 10m". What evolution found is a **run** (~45–55% of each stride airborne, like human running; walking means a foot always planted). We certified the run honestly rather than relabeling it: the gate demands ≥10 m, zero falls, on 5 held-out noise seeds, evaluated on the *saved and reloaded* artifact — but it does **not** constrain flight. A strict low-flight **walk remains the open milestone**: two 1440-cell scans prove no open-loop human-knee gait exists in this sim (feedback is required from step one), and every fitness shape we tried for flight suppression either pinned populations at salvage scores (cliffs) or flattened at the floor (bounded slopes). The full negative-result log is in the commit history — it's the most instructive part of the repo.

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

## Certified numbers (committed artifact, `ml/models/walker.json`)

- Noise-free: 12.5 m in 8.6 s (1.46 m/s), upright, zero falls, knees flexing human-way.
- 5 gate seeds (never trained on): min 12.51 m, **zero falls**.
- Gait: flight fraction 42–53 % (a run); cadence self-modulated around 0.95 Hz.

## Open milestones

- **Strict walk** (<8 % flight) — the fitness-design notes above are the map.
- **Lateral balance** (full 3D) — physics + rig + trainer staged; launches next.
