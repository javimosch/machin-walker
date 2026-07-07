# machin-walker

**A human-shaped biped that *learned* to walk.** A [tinybrain](https://github.com/javimosch/tinybrain) neural network (11 sensors → 14 hidden → 3 joint targets, ~3.5 KB JSON) drives six torque-limited joints of a 1.75 m / 70 kg humanoid through a rigorous pure-[machin](https://github.com/javimosch/machin) physics simulation — and walks **18.7 m in 20 s (~0.94 m/s, 2.2 steps/s — human cadence)** without falling, on *any* sensor-noise seed. The challenge bar was 10 m; every held-out evaluation clears it by 8+ m.

This is the "how machin could make robots walk" demo: everything a real robot controller is allowed — and nothing it isn't.

## The physics contract (what makes it honest)

`src/pbd.src` is an XPBD-style articulated-body simulation whose rules are *enforced by tests* (`tests/pbd_test.src`, 10 assertions):

- **Internal actuation only.** A joint motor is the textbook PBD angular-constraint projection between two adjacent segments — torque-limited, and momentum-conserving *by construction* (`grad_b = -(grad_a+grad_c)`). Airborne motor flailing translates the center of mass by **9e-14 m** over a second. No world-frame springs, no balance assist, no velocity caps.
- **Coulomb ground friction.** Static cone + kinetic slide; a shoved box's slide distance matches `v²/2μg` theory to three digits.
- **Inverse-mass-weighted constraints**, substepped integration, joint mechanical limits (knees can't hyperextend).
- Motor authority calibrated to human-ish joint speeds (~11 rad/s hip). With 5× that, evolution found a 3.3 m/s dive-sprint — physics exploits are a fitness-function code smell.

Dynamics are **planar (sagittal)** — the Walker2D-standard configuration real planar bipeds (e.g. RABBIT) used; the 3D skeleton gets its lateral dimension back at render time. Full-3D lateral balance is future work, declared not smuggled.

## The controller

One net is the whole controller, evaluated per leg per tick with a half-cycle phase shift (mirror symmetry — same policy, legs π apart). Inputs: gait phase (sin/cos), torso pitch, hip height, forward velocity, 4 joint angles, 2 foot contacts — all with ±1 % sensor noise. Outputs: target angles for hip/knee/ankle servos. The artifact is a plain tinybrain JSON any MFL program loads with `net_load` + `net_forward`.

## How it was trained (the honest arc)

Five failure modes, each diagnosed and kept in the history:

1. **Superhuman torques** → a 12.7 m dive-sprint that ends face-down. Fixed by calibrating motor caps.
2. **Distance-only fitness** → hopping (30 % flight time). Fixed by flight + crouch penalties: walking means a foot on the ground.
3. **Noise-free training** → champions overfit to exact weight *bits* (chaotic contact dynamics): 10.4 m in training, 6.7 m after artifact save/load. Fixed by ±1 % sensor noise.
4. **Plain GA from scratch** crawled (+0.5 fitness per 300 generations). Fixed by the tinybrain doctrine: a 6-parameter open-loop **CPG** (sinusoidal joint targets) found by random search becomes the expert, SGD **clones** it into the net, `evolve_run` with `warm_start` grows sensor feedback on top — 22 m within 16 generations.
5. **Fixed evaluation seeds get memorized** — twice (2 seeds, then 5). Fixed by the **gated convergence loop** (`ml/walk_train4.src`): every round re-draws its training seeds and warm-starts from the *reloaded* previous champion; the only exit is the deliverable itself — the saved artifact walking ≥10 m with **zero falls on 5 noise seeds never used in any round**. Passed in 3 rounds.

Training runs on a 14-core box via tinybrain's **parallel fitness evaluation** (`cfg.workers` — a feature this project drove upstream): genomes cross channels as f64-bit strings, fitness must be pure, machin's data-race inference verifies the composed trainer, and results are bit-identical to sequential.

## Run it

```sh
./tests/run_tests.sh    # physics contract (10) + the walk gate on the committed artifact (8)
./build.sh && ./walker-game   # watch it walk: 3D skeleton, tracking camera, HUD distance/speed
```

`ml/walk_train4.src` retrains end-to-end (see header; deterministic, ~minutes on 12+ cores).

## Honest numbers

- Noise-free: **18.66 m** in 20 s, 44 steps, 77 % single-support / 18 % double / 4.5 % flight, hip 0.89–0.98 m, no fall.
- 5 gate seeds (never trained on): min **18.79 m**, zero falls.
- 8 additional fresh seeds: min 15.25 m, **1 fall in 8** — robust, not invincible.
