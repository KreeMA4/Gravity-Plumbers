# Tuning guide

Every number lives in `scripts/core/tuning.gd`, with a comment on each one. Change a value, press Play, and test in **Debug rooms → Ragdoll Playground**, which shows the plumber's state, stiffness and support live.

## Ragdoll feel (try these first)
| Knob | What it does | If it feels wrong |
|---|---|---|
| `JOINT_KP` / `JOINT_KD` | Joint muscle spring and damping. | Jittery limbs: lower KP or raise KD. Floppy limbs: raise KP. Keep `KD` at about 7-10% of `KP`. |
| `UPRIGHT_KP` / `UPRIGHT_KD` | How hard the chest and pelvis stay upright. | Topples while walking: raise KP. Rocks back and forth: raise KD. |
| `RIDE_HEIGHT` | Pelvis height while standing (0.86 m matches the legs). | Feet dangle in the air: lower it. Knees buckle: raise it a little. |
| `RIDE_SPRING` / `RIDE_DAMP` | The hover spring that holds the body up. | Bouncy: raise DAMP. Saggy: raise SPRING. |
| `STIFFNESS_RAGDOLL` | Muscle left while limp. | 0 is a noodle sack; 0.15 is a stiff mannequin. |
| `RAGDOLL_IMPACT_DV` | Velocity change that knocks you out. | Too easy to knock over: raise it (8-10). |
| `GET_UP_TIME`, `DIZZY_TIME` | How long getting up and the wobble afterwards take. | Lower both for snappier recovery. |

## Movement
`WALK_SPEED` (top speed), `WALK_ACCEL` (weight: lower feels heavier), `AIR_CONTROL`, `JUMP_SPEED`, `JUMP_HOLD_FORCE`, `COYOTE_TIME`, `JUMP_BUFFER_TIME`, `TURN_RATE`.

## Walk animation
`WALK_CYCLE_RATE` (cadence), `WALK_LEG_SWING`, `WALK_ARM_SWING`.

## Grabbing
`GRAB_RADIUS` (how close the palm must be), `MAX_CARRY_MASS`, `GRAB_BREAK_DISTANCE` (how far a grab stretches before it lets go), `THROW_BOOST`.

## Magnetic boots
`BOOTS_RANGE`, `BOOTS_STICK_ACCEL`, `BOOTS_SPEED_MULT`, `BOOTS_JUMP_MULT`, `BOOTS_CHARGE_MAX`, `BOOTS_RECHARGE_RATE`.

## Camera
`CAMERA_DISTANCE`, `CAMERA_UP_FOLLOW_TIME` (how fast the world rolls during a shift), `CAMERA_RAGDOLL_SMOOTH`, `CAMERA_RECENTER_SPEED` (0 turns auto-recenter off), `LOOK_SENSITIVITY`.

## Joint limits (in `ragdoll_builder.gd`)
Elbows use hinge limits `-0.15..2.5` and knees `-2.4..0.1` (radians). If, on your device, elbows or knees bend the wrong way, swap the signs of those two pairs. The hinge angle sign in Jolt is UNVERIFIED (see STATUS.md).

## Gameplay pacing
- `LEAK_SLUDGE_RATE`, `CLOG_SLUDGE_RATE`, `SLUDGE_FIX_REWARD`: how fast the station floods.
- `LEAK_SEAL_TIME`, `CLOG_HITS`, `VALVE_TURN_TIME`: how long each job takes.
- `PIPE_SNAP_RADIUS`, `PIPE_SNAP_ANGLE`: how forgiving pipe snapping is.
- `DIFFICULTY`: Chill / Normal / Chaos multipliers for sludge, storm interval, warning seconds and time limits. Chill is meant to be very forgiving.
- `GRAVITY_SHIFT_DURATION`, `GRAVITY_WARNING_*`: shift feel. Warnings are never shorter than 2 s (1 s on Chaos).
- `G_WRENCH_DURATION`, `G_WRENCH_COOLDOWN`, `G_WRENCH_RANGE`.
- `RESPAWN_DELAY`, `FLUSH_TIME_PENALTY`, `TOOL_RESPAWN_TIME`.

## Network
`INPUT_SEND_RATE`, `SNAPSHOT_RATE`, `SNAPSHOT_BYTE_BUDGET`, `INTERP_DELAY` (raise to 0.15 on bad Wi-Fi), `EXTRAPOLATE_MAX`, `STATE_SYNC_RATE`.

## Performance
- `GOO_BLOB_COUNT` (pool size), `MAX_AWAKE_PROPS`.
- `LOW_FPS_THRESHOLD` and `LOW_FPS_SECONDS`: when to suggest lowering quality.
- Quality presets live in `scripts/core/quality.gd` (`PRESETS`).
