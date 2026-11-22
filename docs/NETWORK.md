# Networking

## Model
- The game uses a **host-authoritative listen server**. One player's phone is the host (peer 1). It runs all the physics and all the rules.
- Clients send their input and draw what the host sends them.
- **Solo play is the same code with no clients:** Godot's `OfflineMultiplayerPeer` makes the phone the server.
- All RPCs live on the `NetManager` autoload (`/root/NetManager`), so node paths always match on every peer. Gravity shifts and zone changes are RPCs on `/root/GravityManager`.
- The transport is `TransportENet`, which wraps `ENetMultiplayerPeer` over UDP. A relay or WebRTC transport would only need the same three functions (`create_server`, `create_client`, `get_peer`).

## Ports
| What | Port | Protocol |
|---|---|---|
| Game | 24777 (changeable under Host → Advanced) | UDP (ENet) |
| LAN discovery beacon | 24778 | UDP broadcast, 1 per second |

## Joining
1. **LAN browse:** the host broadcasts a JSON beacon `{"game":"gravity_plumbers","n":room,"l":level,"c":players,"m":max,"v":version,"p":port}` to 255.255.255.255 and to each local subnet's `.255` address. Joiners list rooms they've heard from in the last 4 seconds.
2. **Room code:** Crockford base32 of the IPv4 address (4 bytes) plus the port (2 bytes): 48 bits, padded to 50, giving 10 characters shown as `XXXXX-XXXXX`. Decoding accepts lowercase, spaces and dashes, and maps O to 0 and I/L to 1. See `room_code.gd` and `tests/room_code_test.gd`.
3. **Manual IP and port** (Join → Advanced).
4. **Hotspot:** the host turns on the phone hotspot, and friends join it and use the code. The host's IP is read from the device: Wi-Fi and hotspot interfaces are preferred, mobile data and VPN interfaces are skipped.
5. **Internet (best effort):** the host tries UPnP (`UPNP.discover`, `add_port_mapping`, `query_external_address`) in a worker thread. If it works, the lobby shows an "Internet code". If not, the lobby explains the options: port forwarding, hotspot or LAN, or a VPN such as Tailscale or ZeroTier.

## Messages
| RPC | Direction | Mode | Purpose |
|---|---|---|---|
| `_rpc_hello(version, protocol, name, look)` | client → host | reliable | Handshake. A mismatch is rejected with "Update needed". |
| `_rpc_rejected(msg)` / `_rpc_welcome(room, level, difficulty, version)` | host → client | reliable | Join result. |
| `_rpc_player_list([...])` | host → all | reliable | Names, looks (19 bytes each), ready flags, indices. |
| `_rpc_lobby_info(room, level, difficulty)` | host → all | reliable | The host's picks. |
| `_rpc_set_ready(bool)`, `_rpc_set_look(bytes, name)` | client → host | reliable | Lobby. Clamped by the host. |
| `_rpc_kicked(msg)` | host → client | reliable | Kick. |
| `_rpc_start_level(id, difficulty, simple_rig)`, `_rpc_goto_lobby()` | host → all | reliable | Flow. |
| `_rpc_spawn_player`, `_rpc_despawn_player` | host → all | reliable | Mid-level joins and leaves. |
| `_rpc_request_sync()` → `_rpc_gravity_sync`, `_rpc_level_state_reliable` | client ↔ host | reliable | Late-join catch-up. |
| `_rpc_input(8 bytes)` | client → host | unreliable_ordered, channel 1, 30 Hz | Move (2 × s8), aim (3 × s8), buttons, emote. Rate-limited to 70 per second. |
| `_rpc_snapshot(bytes)` | host → all | unreliable_ordered, channel 2, 20 Hz | Poses. See below. |
| `_rpc_level_state(dict)` | host → all | unreliable_ordered, channel 3, 5 Hz (reliable on completions) | Sludge, timer, work orders, object states. |
| `_rpc_event_remote(name, args)` | host → all or one | reliable | Ducks, toasts, flush effects, host paused, open mirror. |
| `_rpc_results(dict)` | host → all | reliable | The results screen. |
| `_rpc_ping` / `_rpc_pong` | both | unreliable, 1 Hz | Ping. |
| GravityManager `_rpc_begin_shift`, `_rpc_set_field` | host → all | reliable, call_local | Gravity shifts and zones. |

## Snapshot format (`snapshot_sync.gd`)
- Header: `u8 version, u16 seq, f32 host_time`, 7 bytes.
- **Per plumber** (11 parts, about 151 bytes):
  - `u8 index, u8 state, u8 flags (boots, celebrate, emote id), u8 part count`.
  - Pelvis position (3 × f32), pelvis quaternion (3 × s16, smallest-three style with w ≥ 0), velocity (3 × s16, ±40 m/s) and local up (3 × s8).
  - Each other part: position relative to the pelvis (3 × s16, ±3 m) plus quaternion (3 × s16).
- **Props:** `u16 net id, 3 × f32 position, quaternion`, 20 bytes each. Moving props come first. Sleeping props are refreshed now and then.
- **Goo:** `u8 index, 3 × s16 position`, 7 bytes each.
- Props and goo are trimmed to stay under **1200 bytes** (`Tuning.SNAPSHOT_BYTE_BUDGET`).
- Network ids are assigned **by build order**. Every peer builds the level from the same data in the same order, so prop ids match with nothing sent.

## Client side
- Plumbers and props are frozen, kinematic **puppets**, built with the host's rig type.
- They're drawn about 100 ms in the past (`Tuning.INTERP_DELAY`), interpolated between snapshots, and extrapolated with the pelvis velocity for up to 250 ms on packet loss.
- Client clock offset = smoothed `local_time - host_time`.

## Bandwidth estimate (4 players)
- **Snapshots:** about 1.2 KB × 20/s = **24 KB/s down per client** (worst case), plus about 1 KB/s of level state.
- **Input:** 8 bytes plus about 30 bytes of ENet/UDP overhead × 30/s ≈ **1.1 KB/s up per client**.
- The host uploads about 25 KB/s per client (≈75 KB/s for 3 clients). That's fine on LAN and hotspots, and within the 40 KB/s per-client target.
- The debug overlay shows the real numbers from ENet's statistics.

## Robustness
- All client data is clamped: names to 16 characters; looks are re-parsed and clamped; input is sanitised (finite, unit aim, bit mask); unknown peers are ignored.
- A client leaving despawns their plumber and releases every grab on them.
- The host leaving sends everyone back to the menu with "The host left the game."
- Connect timeout is 8 s, with a Cancel button.
- Kicks send a message first, then disconnect.
- If the host backgrounds the app, clients see "The host paused the app...".

## Known limit
With pure host authority, **a client feels the round trip on their own plumber**: press → host → snapshot → about 2 × ping + 100 ms of interpolation delay. That's fine on LAN and hotspots (about 120-160 ms total), but sluggish over the internet. A future improvement would be client-side prediction for the local pelvis.

## Testing with one phone
- **Lobby → "+ Test bot"** adds a fake remote player. Its input is encoded into the same 8-byte packets and passed through the simulated **Lag** and **Loss** settings before the host applies it.
- **Desktop:** run `godot -- --server` in one window and `godot -- --client=127.0.0.1` in another. Add `--port=NNNN` to change the port.
