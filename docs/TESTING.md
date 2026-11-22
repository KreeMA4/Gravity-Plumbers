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

## M4: Grab and tools
- [ ] In the Ragdoll Playground, walk to the yellow **TOOLS** rack (to your right). Hold **GRAB R** on a tool: it snaps into your right hand and the Use button label changes.
- [ ] Tap **GRAB R** again: you drop the tool.
- [ ] **Plunger:** aim at a wall and tap USE (label "STICK"): it sticks. Now tap **Gravity**: you don't tumble (braced). Release USE to unstick.
- [ ] **Pipe wrench:** walk up to a bot and tap USE ("BONK"): the bot goes floppy and stars pop.
- [ ] **Duct tape:** tap USE on a crate: it freezes in place for about 10 s.
- [ ] **G-Wrench:** aim at a crate and tap USE ("ZAP"): a cyan beam appears and the crate falls toward the direction you aimed for 8 s. The label then counts down the 15 s cooldown. Aim at the ceiling and ZAP: YOU fall up onto the ceiling for 8 s.
- [ ] Hold GRAB on a bot, then swing around: the bot flails, and letting go throws it.
- [ ] Throw a tool out of the window: about 20 s later it reappears on the rack with a sparkle.

## M5: Plumbing gameplay
Main menu → Debug rooms → **Plumbing Workshop**.
- [ ] The HUD shows: the SLUDGE meter and a timer at the top, the WORK ORDERS list on the left (tap ORDERS to collapse it), and the gravity arrow at the bottom.
- [ ] DISPATCH-O-TRON says hello in a subtitle box, with blippy gibberish (once audio exists, M10).
- [ ] The pink leak on the back wall sprays goo and the sludge meter rises. Grab the **tape** from the rack and hold USE on the leak: a green ring grows, then the leak seals and the order ticks off.
- [ ] The red valve order unlocks only after the leak is done (ordered). Hold USE with the **wrench** on the valve: it spins and completes.
- [ ] Carry the loose teal pipe to the see-through gap on the back wall: it snaps in when lined up (vertical).
- [ ] Stab the purple clog with the **plunger** 6 times: it pops and launches goo blobs.
- [ ] Throw both goo canisters into the glass tank: the counter goes "8 / 8" and confetti pops.
- [ ] Pull the yellow **gravity switch** (USE next to it): 3-2-1 warning, then the floor becomes the ceiling. Unbraced plumbers tumble.
- [ ] The vent in the floor glows red, then burps goo and pushes you up.
- [ ] Every 45 s or so a gravity storm hits, with a siren, a flashing red screen edge and a countdown.
- [ ] After a ceiling flip, grab the golden duck near the ceiling: "A golden duck!"
- [ ] Finishing all orders shows the Results screen with stars, time and awards.
- [ ] Solo can never fail: the sludge stops at 95%.

## M6: Hub and Level 1
- [ ] Main menu → **Play Solo** puts you in **The Rusty Pipe** hub: a warm room with a big window and a skylight. There's no sludge meter or timer.
- [ ] The tool rack is on the left wall, the practice gravity switch and rail on the right, and the JOB CONSOLE at the back.
- [ ] USE at the console opens **PICK A JOB**, with a difficulty choice (Chill / Normal / Chaos) and level buttons showing your stars.
- [ ] Pick **1. Orbital Bathroom**. Then:
  - [ ] Tape the sink leak (tape from the rack). The shower leak and the toilet clog unlock.
  - [ ] Tape the shower leak, and plunge the toilet clog 4 times.
  - [ ] The switch order unlocks. Hold the rail with GRAB (or turn BOOTS on), then pull the switch: the warning counts down and gravity flips.
  - [ ] On the ceiling, tape the ceiling leak and crank the main valve with the wrench.
  - [ ] The results screen shows 1-3 stars. **Back to Hub** returns to the hub.
- [ ] Reopen the console: the bathroom shows your stars (saved). Close and restart the game: the stars are still there.
- [ ] Bonus: find the golden duck in the bathroom (hint: near the ceiling cabinet).

## M7: Networking
You need 2 phones on the same Wi-Fi, or 1 phone and the test bot.
- [ ] **Host:** Main menu → Host Game → HOST tab → Start Hosting. The lobby shows a room code, your local IP and a UPnP message.
- [ ] **Join (phone 2):** Main menu → Join Game. The host's room appears under "Games nearby" within about 2 s. Tap it. The joiner lands in the lobby and both phones list both plumbers, with 3D previews behind the lists.
- [ ] Join by typing the room code instead, in lowercase with no dash: it still works.
- [ ] Joiner taps I'M READY. The host's START button lights up. Start: both phones load the level.
- [ ] Both plumbers move smoothly on both screens. The joiner's controls feel slightly delayed (expected, see NETWORK.md).
- [ ] Grab each other, carry crates, tape leaks: the progress shows on both phones, and the sludge meter, timer and order list match.
- [ ] Gravity switch: the warning and the shift happen on both phones at the same time.
- [ ] The joiner leaves (pause → Quit): the host sees "X left the station." and their plumber disappears.
- [ ] The host quits: the joiner returns to the menu with "The host left the game."
- [ ] **Hotspot:** the host turns on the phone hotspot, phone 2 joins it, and you join with the code.
- [ ] **One phone:** in the lobby tap "+ Test bot", set Lag 250ms / Loss 5%, and Start. A bot plumber wanders around the level.
- [ ] Debug overlay (three-finger tap): ping and KB/s are shown, with under about 40 KB/s down on the client.
- [ ] Mid-level join: start a level, then join from phone 2. They appear at a spawn pad.

## M8: Customisation
- [ ] The main menu background shows YOUR plumber idling (bobbing, looking around) in front of the window.
- [ ] Main menu → **Customize**: category tabs on the left, a spinning 3D preview in the middle (drag to spin it), and options on the right.
- [ ] Tapping an option changes the preview immediately, with a little hop and squash.
- [ ] Every category has at least 6 variants. Locked items say "LOCKED / N ducks".
- [ ] **RANDOMIZE!** shakes the button and rerolls everything. **lock** a category (it turns to LOCK) and randomize again: that category stays the same. **Colours only** changes only colours. **Undo** steps back.
- [ ] **Outfit 1-3:** hold one for about 1 second to save into it, tap it to wear it.
- [ ] **Done** saves. Restart the game: your look is still there.
- [ ] In the hub, USE on the **MIRROR** opens the same screen as an overlay.
- [ ] Online: change your outfit in the lobby (Customise): the other phone's 3D lobby preview updates.
- [ ] In a level, other plumbers wear their chosen outfits.

## M9: Levels 2-5, boss, difficulty, mid-level join
Pick each level at the hub console (try different difficulties).
- [ ] **2. Zero-G Cafeteria:** the right half floats (bluish zone) and food drifts around. Floating with the stick plus camera works, and you can grab tables. ZAP a canister with the G-Wrench and it falls the way you aimed. The two-player cooler valve turns at half speed solo. Plunging the chute clog works after anchoring with the plunger.
- [ ] **3. Asteroid Waterworks:** you start on top of a purple rock and can walk ALL the way round it (the camera rolls with you). Both leaks, including the one at the south pole, are reachable. Float the bridge piece into the gap between the rocks; then jump across to the little moon (or climb the bridge pipe) and fill its tank. Drifting into deep space flushes you and you respawn.
- [ ] **4. Spin-Cycle Habitat:** every ~32 s (Normal), down moves FLOOR 1 → 2 → 3 → 4 with a warning each time. The labels FLOOR 1-4 read upright when their wall is down. The relay switch on FLOOR 3 drops everything onto FLOOR 4. The wall tank only fills while FLOOR 4 is down.
- [ ] **5. Reactor Plumbing Panic:** three rooms, storms about every 40 s. After the feed pipe is fixed, THE GREAT CLOG wakes up in the core: goo blobs (from vents, leaks and storms) and thrown canisters count down "N / 30". It burps goo back out now and then, and bursts with confetti at 30.
- [ ] Both room switches (Coolant + Waste) together complete their order and point the reactor gravity sideways.
- [ ] **Chill** gives longer warnings (4 s), slower sludge and fewer storms; **Chaos** gives 1.5 s warnings and more storms.
- [ ] With 2 phones: start any level, then have the second phone join mid-level. It spawns at a pad and sees the current progress.

## M10: Polish
- [ ] **Audio:** UI clicks, squelchy footsteps, a jump boing, landing thuds, grab squeaks, impacts, plunger thwock, wrench clank, tape rip, leak hiss, valve creak, pipe snap, goo splats and glugs, a gravity siren then whoomp, boot clamp, flush swirl, dice rattle, an order-done jingle, a level-clear fanfare and a fail wah-wah all play.
- [ ] Menu music is calm. Gameplay music is a bouncy groove. During a gravity warning a tense layer fades in, then fades out. Loops have no audible gap.
- [ ] DISPATCH-O-TRON lines play as gibberish blips with subtitles.
- [ ] **Juice:** dust puffs when landing, a cyan ring on jumps, stars on bonks, squash and stretch on hard hits, a brief freeze on huge hits (Settings → Hit-stop), and camera shake (Settings → Reduce screen shake lowers it).
- [ ] **Settings:** every slider and toggle changes something live (volumes, button size and opacity, left-handed, single grab, deadzone, look sensitivity, comfort camera, show FPS). Quality Low / Medium / High visibly changes resolution, shadows and outlines. "Auto" re-runs the 4-second benchmark on the main menu.
- [ ] **Blob shadows** under plumbers on Medium and High.
- [ ] **Performance:** with 4 plumbers in a level (use lobby test bots), the debug overlay shows about 60 FPS and fewer than 250 draw calls on a mid-range phone. Low quality stays at 30 FPS or more on a weak phone.
- [ ] **Soak test:** Debug rooms → Physics Soak Test runs for 2 minutes and ends with "PASSED" (no NaN, no out-of-bounds).
- [ ] **Android lifecycle:** press Home mid-level, then come back: solo is paused, and online clients see "The host paused the app...".
- [ ] **Export:** Project → Export → Android → Export Project produces an APK that installs and runs.
