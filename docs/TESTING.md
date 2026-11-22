# Manual phone tests

Tick these off on your phone after each milestone. If anything fails, copy the red errors from **Debugger → Errors** and send them to Claude.

## M0: Foundation
- [ ] The project imports without errors (watch the Output panel during import).
- [ ] Press Play: the main menu appears in landscape, with big readable buttons.
- [ ] Buttons for later milestones are greyed out and marked "(soon)".
- [ ] A three-finger tap toggles the debug overlay (FPS, bodies, gravity, build M0).
- [ ] Rotate the phone 180°: the game flips to the other landscape side.
- [ ] Close and reopen the game: no errors (save.json is created in user://).

## M1: Gravity core
- [ ] Main menu → Debug rooms → **Gravity Test Room**: crates fall to the green floor.
- [ ] Tap **Cycle gravity** 6 times. Each time, the crates fall toward a different wall (+Y, +X, -X, +Z, -Z, then back to -Y), and the camera rolls smoothly so the new floor ends up at the bottom.
- [ ] **Shift (warned)**: the HUD arrow flashes red with a countdown of at least 2 seconds before gravity moves.
- [ ] **Zero-G zone**: crates inside the bluish box float and slowly stop drifting.
- [ ] **Planetoid**: crates near the purple ball are pulled onto it from every side.
- [ ] Debug rooms → **Run Tests**: every line says "ok" and the header is green.

## M2: Look and shaders
- [ ] The main menu background shows a room with a big framed window onto twinkling stars, a nebula and a planet that slowly drifts.
- [ ] Debug rooms → **Look Test Room**: two rooms joined by a doorway, with flat cel-shaded colours (3 light bands) and a soft rim light.
- [ ] Pipes are smooth tubes with rounded bends and flanges. The orange pipe glows a little.
- [ ] The three crates have thin dark outlines. The walls do not.
- [ ] The goo blobs wobble and glow lime and purple.
- [ ] The debug overlay shows fewer than 250 draw calls in this room.
- [ ] Nothing renders inside-out. If pipes look hollow or the outlines cover whole objects, report it: the triangle winding is wrong.

## M3: Ragdoll plumber
- [ ] Debug rooms → **Ragdoll Playground**: a chunky plumber with big googly eyes and a mustache stands on the floor.
- [ ] The left thumb moves (a joystick appears under it). The legs swing in a walk cycle and the arms swing opposite.
- [ ] Dragging on the right half orbits the camera. After a second of walking, it settles back behind you.
- [ ] **JUMP** jumps. Holding it jumps slightly higher. Walking off the stairs and jumping right away still works (coyote time).
- [ ] **FLOP** makes the plumber go limp. After about 1-2 seconds it wobbles back up by itself. **UP!** speeds this up.
- [ ] Tap **Gravity** (top bar): the plumber tumbles (unbraced), the camera rolls smoothly, and they get up on the new floor.
- [ ] **BOOTS** then **Gravity**: the plumber stays stuck to the floor (braced), and the HUD ring shows the boot charge draining.
- [ ] Hold **GRAB L/R** near a crate: the arm reaches where you look, then grabs and carries the crate. Let go mid-swing to throw it.
- [ ] Hold GRAB on the grey bar at chest height while gravity flips: you hang on (braced).
- [ ] **+ Bots** spawns 3 wandering plumbers. The debug overlay should still show 60 FPS on a mid-range phone.
- [ ] Walk off into space if you can (through a window gap, or with gravity pointing at the window): you get flushed and respawn after 3 s.
