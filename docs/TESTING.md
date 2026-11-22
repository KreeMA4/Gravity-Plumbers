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
