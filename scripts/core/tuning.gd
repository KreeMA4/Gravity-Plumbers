extends Node
## Tuning (autoload)
## -----------------------------------------------------------------------------
## EVERY number that changes how the game *feels* lives here, with a comment.
## Edit a value, press Play, feel the difference. No other file needs touching.
##
## Units: metres, seconds, kilograms, radians unless the comment says otherwise.
## See docs/TUNING.md for advice on which knobs to turn first.

# --- Build info --------------------------------------------------------------
var GAME_VERSION: String = "0.10.0"     ## Shown in menus and checked on join.
var PROTOCOL_VERSION: int = 3           ## Bump when network messages change.
var MILESTONE_ID: String = "M10-RC1"        ## Shown in the debug overlay.

# --- Gravity -----------------------------------------------------------------
var GRAVITY_STRENGTH: float = 9.8       ## m/s^2 of normal station gravity.
var GRAVITY_SHIFT_DURATION: float = 0.6 ## Seconds the global "down" takes to rotate (0.4-0.8 feels good).
var GRAVITY_WARNING_NORMAL: float = 3.0 ## Seconds of warning before a shift on Normal/Chill.
var GRAVITY_WARNING_CHAOS: float = 1.5  ## Seconds of warning on Chaos (never below 1.0).
var ZERO_G_DRAG: float = 0.6            ## Air drag inside zero-G zones so floating stays controllable.
var ZERO_G_THRUST: float = 3.0          ## m/s^2 a plumber can push itself around in zero-G.
var MAX_BODY_SPEED: float = 40.0        ## Hard velocity clamp for every dynamic body (stops explosions).
var G_WRENCH_DURATION: float = 8.0      ## Seconds the G-Wrench override lasts on its target.
var G_WRENCH_COOLDOWN: float = 15.0     ## Seconds before the G-Wrench can be used again.
var G_WRENCH_RANGE: float = 12.0        ## Metres the G-Wrench beam reaches.

# --- Plumber body ------------------------------------------------------------
var PLUMBER_MASS_PELVIS: float = 12.0   ## Heavy pelvis = stable.
var PLUMBER_MASS_CHEST: float = 10.0
var PLUMBER_MASS_HEAD: float = 4.0
var PLUMBER_MASS_LIMB: float = 2.0      ## Light limbs flop around nicely.
var PLUMBER_LINEAR_DAMP: float = 0.15
var PLUMBER_ANGULAR_DAMP: float = 1.5   ## Higher = less spinning like a top when flung.
var FOOT_FRICTION: float = 1.2          ## Grippy feet.
var SWING_FOOT_FRICTION: float = 0.05   ## A foot in its swing phase slides instead of catching the floor.
var STANCE_FOOT_FRICTION: float = 0.25  ## A planted foot while walking: placed, but not a pivot that tips you over.
var BODY_FRICTION: float = 0.35         ## Slippery everything else.

# --- Active ragdoll controller ----------------------------------------------
var STIFFNESS_ACTIVE: float = 1.0       ## Joint muscle strength while controlled.
var STIFFNESS_RAGDOLL: float = 0.05     ## Leftover muscle when limp (not a noodle sack).
var STIFFNESS_DIZZY: float = 0.3        ## Wobbly muscle right after getting up.
var JOINT_KP: float = 420.0             ## Spring strength pulling each joint to its pose.
var JOINT_KD: float = 32.0              ## Damping on each joint (too low = jitter, too high = stiff).
var STANCE_PRESS: float = 0.015          ## A planted foot aims this far (m) below the floor so it bears weight.
var HIP_REACTION: float = 0.0          ## Share of hip-muscle push given back to the pelvis.
var LEG_FEED_FORWARD: bool = true      ## Legs also match the speed of their moving gait targets.
var HIPS_UPRIGHT_FRAME: bool = true     ## Hip targets in the upright walking frame (true) or relative to the pelvis.
var LEG_STRENGTH_ON_FEET: float = 2.6   ## Leg muscle multiplier while standing/walking (ragdoll still scales it down).
var JOINT_MAX_ANG_ACCEL: float = 900.0  ## Clamp on joint correction (rad/s^2) so nothing explodes.
var UPRIGHT_KP: float = 260.0           ## How hard chest and pelvis turn to stay upright.
var UPRIGHT_KD: float = 26.0            ## (legacy PD gains, kept for reference; the servo below is used)
var UPRIGHT_SERVO_RATE: float = 12.0    ## Upright correction speed (1/s): ~0.08 s to close a tilt.
var UPRIGHT_SERVO_BLEND: float = 0.85   ## Per-tick blend toward the corrective spin (higher = stiffer).
var UPRIGHT_MAX_SPIN: float = 14.0      ## Cap on the corrective spin (rad/s).
var TURN_RATE: float = 9.0              ## How fast the body turns to face where it walks (1/s).
var RIDE_HEIGHT: float = 0.86           ## Pelvis height above the floor while standing.
var RIDE_SPRING: float = 140.0          ## Spring holding the pelvis at ride height.
var RIDE_DAMP: float = 18.0
var GROUND_PROBE_LENGTH: float = 1.25   ## Ray length (from pelvis, along -up) to find the floor.

# --- Movement ----------------------------------------------------------------
var WALK_SPEED: float = 4.5             ## Top running speed in m/s.
var WALK_ACCEL: float = 9.0             ## How quickly you reach top speed (weighty < 10 < snappy).
var AIR_CONTROL: float = 0.25           ## Fraction of steering you keep in the air.
var JUMP_SPEED: float = 4.6             ## Upward speed added by a jump.
var JUMP_HOLD_FORCE: float = 7.0        ## Extra up-acceleration while holding jump.
var JUMP_HOLD_TIME: float = 0.22        ## How long holding jump keeps helping.
var COYOTE_TIME: float = 0.12           ## You can still jump this long after walking off a ledge.
var JUMP_BUFFER_TIME: float = 0.1       ## A jump pressed this early before landing still counts.
var WALK_CYCLE_RATE: float = 2.3        ## Steps per metre-ish (higher = faster little legs).
var WALK_LEG_SWING: float = 0.75        ## Leg swing amplitude (radians).
var WALK_ARM_SWING: float = 0.55        ## Arm swing amplitude (radians).

# --- Ragdoll triggers & recovery -------------------------------------------
var RAGDOLL_IMPACT_DV: float = 7.5      ## Velocity change in one physics step that knocks you out.
var RAGDOLL_MIN_TIME: float = 1.2       ## Minimum seconds spent limp.
var RAGDOLL_MAX_TIME: float = 4.0       ## Force a get-up after this long even if still sliding.
var RECOVER_MAX_SPEED: float = 1.6      ## Must be moving slower than this to get up.
var GET_UP_TIME: float = 0.9            ## Seconds to ramp muscles back up.
var DIZZY_TIME: float = 0.7             ## Seconds of extra wobble after getting up.
var SWING_RAGDOLL_SPEED: float = 9.0    ## Being swung faster than this while held makes you limp.

# --- Grabbing & carrying -----------------------------------------------------
var GRAB_RADIUS: float = 0.2            ## Hand sphere radius used to find things to grab.
var GRAB_ARM_REACH: float = 0.75        ## How far the hand reaches toward the aim point.
var PICKUP_RANGE: float = 1.9           ## Interact picks up items within this distance (m) of your middle...
var PICKUP_MIN_DOT: float = 0.35        ## ...that are roughly in front of you (cos of the max angle, about 70 deg).
var MAX_CARRY_MASS: float = 60.0        ## Heavier dynamic things can't be grabbed (but can be hung from).
var GRAB_BREAK_FORCE: float = 2500.0    ## Not used by Jolt directly; we break the grab past this stretch.
var GRAB_BREAK_DISTANCE: float = 0.9    ## Hand-to-grab-point distance that breaks a grab.
var THROW_BOOST: float = 1.25           ## Multiplies the velocity of things you let go of mid-swing.

# --- Magnetic boots ----------------------------------------------------------
var BOOTS_RANGE: float = 1.2            ## Metres the boot ray searches for a surface.
var BOOTS_STICK_ACCEL: float = 18.0     ## Pull toward the surface while boots are on.
var BOOTS_SPEED_MULT: float = 0.5       ## Movement speed multiplier with boots on.
var BOOTS_JUMP_MULT: float = 0.35       ## Jump multiplier with boots on.
var BOOTS_CHARGE_MAX: float = 6.0       ## Seconds of boot use from full.
var BOOTS_RECHARGE_RATE: float = 0.5    ## Charge seconds regained per second when off.
var BOOTS_UP_SMOOTH: float = 6.0        ## How fast "up" follows the surface normal.

# --- Camera ------------------------------------------------------------------
var CAMERA_DISTANCE: float = 5.0
var CAMERA_HEIGHT: float = 1.0          ## Look-at point above the pelvis.
var CAMERA_PITCH_MIN: float = -1.1      ## Radians (looking up).
var CAMERA_PITCH_MAX: float = 1.2       ## Radians (looking down).
var CAMERA_UP_FOLLOW_TIME: float = 0.5  ## Seconds for the camera's up to follow gravity.
var CAMERA_UP_FOLLOW_COMFORT: float = 0.2
var CAMERA_FOLLOW_SMOOTH: float = 10.0  ## Higher = camera sticks tighter to the player.
var CAMERA_RAGDOLL_SMOOTH: float = 4.0  ## Softer follow while ragdolled so it never whips.
var CAMERA_RECENTER_SPEED: float = 1.2  ## Auto-recenter behind movement (rad/s). 0 disables.
var LOOK_SENSITIVITY: float = 0.006     ## Radians per pixel of drag (scaled by Settings).
var SHAKE_DECAY: float = 3.0

# --- Touch controls ----------------------------------------------------------
var JOYSTICK_RADIUS: float = 140.0      ## Pixels (at 1080p) the joystick knob can travel.
var JOYSTICK_DEADZONE: float = 0.12     ## Default; players can change it in Settings.
var BUTTON_SIZE: float = 150.0          ## Default button diameter in pixels at 1080p (>56dp).

# --- Plumbing gameplay -------------------------------------------------------
var LEAK_SLUDGE_RATE: float = 1.2       ## Sludge % per second per open leak (Normal).
var LEAK_SEAL_TIME: float = 2.0         ## Seconds of taping to seal a leak.
var CLOG_SLUDGE_RATE: float = 0.4       ## Sludge % per second per unfinished clog.
var CLOG_HITS: int = 6                  ## Plunger stabs to pop a clog.
var VALVE_TURN_TIME: float = 2.5        ## Seconds of wrench-turning per valve.
var VALVE_TWO_PLAYER_WINDOW: float = 0.4## Two players must be turning within this time of each other.
var SLUDGE_FIX_REWARD: float = 8.0      ## Sludge % removed when a work order completes.
var PIPE_SNAP_RADIUS: float = 0.6       ## Pipe pieces snap into a port within this distance.
var PIPE_SNAP_ANGLE: float = 0.6        ## ...and within this angle (radians).
var GOO_BLOB_COUNT: int = 60            ## Pooled sludge blobs per level (budget).
var GOO_BLOB_RADIUS: float = 0.14
var RESPAWN_DELAY: float = 3.0          ## Seconds before a flushed plumber respawns.
var FLUSH_TIME_PENALTY: float = 5.0     ## Seconds added to the team time per flush.
var TOOL_RESPAWN_TIME: float = 20.0     ## A tool lost in space returns to its rack after this.
var KILL_DISTANCE: float = 80.0         ## Drift this far from the level centre = flushed.

# --- Difficulty multipliers (Chill / Normal / Chaos) ------------------------
var DIFFICULTY: Dictionary = {
	0: {"name": "Chill", "sludge": 0.45, "storm_interval": 1.6, "warning": 4.0, "time": 1.6},
	1: {"name": "Normal", "sludge": 1.0, "storm_interval": 1.0, "warning": 3.0, "time": 1.0},
	2: {"name": "Chaos", "sludge": 1.5, "storm_interval": 0.6, "warning": 1.5, "time": 0.8},
}

# --- Network -----------------------------------------------------------------
var DEFAULT_PORT: int = 24777           ## Game port (UDP).
var DISCOVERY_PORT: int = 24778         ## LAN beacon port (UDP broadcast).
var MAX_PLAYERS: int = 4                ## Can be raised to 6.
var INPUT_SEND_RATE: float = 30.0       ## Client input packets per second.
var SNAPSHOT_RATE: float = 20.0         ## Host snapshots per second.
var SNAPSHOT_BYTE_BUDGET: int = 1200    ## Bytes per snapshot (props are trimmed to fit).
var INTERP_DELAY: float = 0.1           ## Client render delay for smooth interpolation.
var EXTRAPOLATE_MAX: float = 0.25       ## Max seconds to extrapolate on packet loss.
var CONNECT_TIMEOUT: float = 8.0        ## Seconds before "Connecting..." gives up.
var STATE_SYNC_RATE: float = 5.0        ## Gameplay object state updates per second.

# --- Audio -------------------------------------------------------------------
var MAX_VOICES: int = 24                ## Concurrent positional sounds.
var SAME_SOUND_COOLDOWN: float = 0.06   ## Same sound can't retrigger faster than this.

# --- Performance budgets -----------------------------------------------------
var MAX_AWAKE_PROPS: int = 40
var LOW_FPS_THRESHOLD: float = 26.0     ## Sustained FPS below this suggests lowering quality.
var LOW_FPS_SECONDS: float = 8.0


## Returns a difficulty setting value, e.g. diff("sludge").
func diff(key: String) -> float:
	var d: Dictionary = DIFFICULTY.get(GameState.difficulty, DIFFICULTY[1])
	return float(d.get(key, 1.0))


## Warning seconds before a gravity shift for the current difficulty.
func gravity_warning_time() -> float:
	return maxf(1.0, diff("warning"))
