---
name: zynthian
description: Consolidated knowledge for working on this user's Zynthian synth (Raspberry Pi 5, V5 controller). Use when the user asks about Zynthian UI, LV2 plugins (especially JE8086), preset workflows, V5 button bindings, snapshot/chain behavior, or Zynthian source-code patches.
---

# Zynthian working knowledge

This skill consolidates everything established across prior sessions about this user's specific Zynthian setup. Treat sections as authoritative unless the codebase or live system contradicts them — Zynthian updates regularly and any local patches we've applied may be reverted by upstream.

## Restoration kit (read this first after any Zynthian update or reformat)

**Location:** `/zynthian/zynthian-my-data/zynthian-custom/` — on the user-data partition, survives package upgrades. **Public mirror:** https://github.com/smatheusale/zynthian-custom — clone this on any fresh install before running `restore.sh`.

**Contents:**
- `RESTORE.md` — full runbook with manual fallback code blocks for the engine patch.
- `restore.sh` — one-shot reapply (engine patch via `git apply`, cache, bundles, tooling, service restart).
- `verify.sh` — 11-check sanity test, exits non-zero on any failure.
- `refresh.sh` — re-snapshot the current state into the kit after further edits.
- `baseline.txt` — ZynthianOS version, zynthian-ui commit, capture timestamp.
- `engine/zynthian_engine_jalv.patch` — single git diff covering all engine changes.
- `engine/zynthian_engine_jalv.full.py` — full known-good copy as fallback.
- `cache/presets_JE8086.json`, `bundles/JE8086.presets.lv2/`, `bundles/JE8086_Factory.presets.lv2/` — preset data.

**Standard workflow:**

| Situation | What to do |
|---|---|
| Zynthian package upgrade reverted our engine patch | `cd /zynthian/zynthian-my-data/zynthian-custom && ./restore.sh && ./verify.sh` |
| `git apply` fails (upstream rewrote the engine) | The kit now patches **four** `zynthian-ui` files (`engine/*.patch`, applied by `restore.sh`): `zynthian_engine_jalv.py` (symbols `get_preset_list`, `set_preset`, `_dispatch_firmware_midi`, `add_processor`/`_load_default_preset`, + `MIDI Out:` early-return in `proc_poll_parse_line`), `zynthian_engine.py` (`needs_set_preset_after_restore` base flag), `zynthian_engine_fluidsynth.py` (sets that flag), `zynthian_state_manager.py` (`load_snapshot` post-restore `set_preset` re-fire). Re-apply each manually from the matching `engine/*.full.py` if the patch won't apply. |
| Fresh format / new SD card | First install the JE8086 LV2 plugin (vendor installer), then run `restore.sh`. Off-device backup of `/zynthian/zynthian-my-data/zynthian-custom/` is the user's responsibility — ~600 KB, `rsync`-friendly. |
| After making more local edits | `./refresh.sh` updates the patch, copies the cache and bundles back into the kit, and rewrites `baseline.txt`. |
| Confirming everything's wired up | `./verify.sh` |

When the user mentions "I updated Zynthian", "I formatted", "I'm on a new SD card", or "things broke after the upgrade" — open `RESTORE.md` first.

## User & platform

- Hardware: Raspberry Pi 5 Model B Rev 1.1, **V5 controller** (touchkeypad + 4 encoders), 800×480 DSI display.
- OS: ZynthianOS 2601, Linux 6.12.87+rpt-rpi-2712, Python 3.11.2, runs as `root`.
- User installs **third-party LV2 plugins** (The Usual Suspects — Osirus, JE8086; NodalRed2x; VirtualJV) and wants them to integrate cleanly with Zynthian's display + web admin.
- Preference: prefer fixes via Zynthian's own conventions (user bundles in `/zynthian/zynthian-my-data/presets/lv2/`, regenerating `presets_*.json` cache) over editing vendor files in `/usr/local/lib/lv2/` (clobbered on package upgrade).
- Memory hooks: Stop + SessionStart hooks are configured (~/.claude/settings.json). At session end, do a real memory review and save anything notable. At session start, the load-confirmation systemMessage is intentional — don't suppress.

## Adding LV2 user presets

Zynthian discovers banks/presets via lilv (LV2_PATH includes `/zynthian/zynthian-my-data/presets/lv2/`) and caches to `/zynthian/config/jalv/presets_<PluginName>.json`.

1. Bundle dir: `/zynthian/zynthian-my-data/presets/lv2/<Name>.presets.lv2/`
2. `manifest.ttl` declares each `pset:Bank` and `pset:Preset` (with `lv2:appliesTo <plugin-uri>`, `pset:bank <bank-uri>`, `rdfs:label`, `rdfs:seeAlso <preset-file.ttl>`).
3. Preset file: either `lv2:port` value list (e.g. Dexed) or `state:state [...]` (e.g. Osirus, JE8086).
4. Refresh cache:

```python
import sys; sys.path.insert(0, '/zynthian/zynthian-ui')
from zyngine import zynthian_lv2
zynthian_lv2.generate_plugin_presets_cache('<plugin-uri>', refresh=True)
```

Reference bundle to crib from: `/zynthian/zynthian-my-data/presets/lv2/dexed-DCDCollection.lv2/` (port-value style).

## Firmware-emulator plugins (JE8086 / NodalRed2x / VirtualJV)

These plugins emulate real hardware DSPs (Roland JD-800/JP-8000, etc.). They honor LV2 `state:state` restore **only at plugin instantiation, not on a running instance**. Tap-load on a running chain does not change the patch — including the vendor's own "default" preset.

**Workaround in `/zynthian/zynthian-ui/zyngine/zynthian_engine_jalv.py`:**

- `get_preset_list` reads optional `info['midi_bank_select']` (`[msb, lsb, pc]`) or `info['midi_pc']` (int) from the cache and surfaces it as `preset[1]`.
- `set_preset` sends the LV2 preset URI to jalv (harmless), then `_dispatch_firmware_midi(processor, chan, midi_info)` sends MIDI **via the chain's own zmop output** (NOT a global channel send — fixed 2026-06-29, see #1705 below):
  - `[msb, lsb, pc]` → `zmop_send_ccontrol_change(zmop, chan, 120/123, 0)` (All Sound/Notes Off), then `zmop_send_ccontrol_change(zmop, chan, 0, msb)` + `(…, 32, lsb)` + `zmop_send_program_change(zmop, chan, pc)`.
  - `int` → All Sound/Notes Off, then `zmop_send_program_change(zmop, chan, prg)`.
  - Else → no MIDI; standard LV2 state-restore path only.
  - `zmop = processor.chain.zmop_index`; `chan = midi_chan_engine` (0 for dsp56300). **Never use `ui_send_*`/`zynmidi.set_midi_*` here** — those broadcast on the MIDI channel and hijack any layer-mate sharing it (that bug made a layered FluidSynth play GM Violin/strings; see #1705).
  - Snapshot restore re-fires this: `zynthian_state_manager.load_snapshot` re-calls `set_preset(force_set_engine=True)` after `request_midi_connect(True)` for engines flagged `needs_set_preset_after_restore` (replaces the old 1.5s `Timer` hack, which is gone).
- `set_preset` returns `True` so the GUI follows the standard Zynthian flow (purge bank history, jump to `chain_control`). Returning `None` to keep "audition" mode broke screen-history navigation and was reverted 2026-06-08.
- Empty-URL `(none)` blank entry hits the existing `if not preset[0]: return` early-return → no MIDI sent, GUI stays on preset list. To add it: prepend `{"label": "(none)", "url": ""}` to the first bank's `presets` list in `presets_<Plugin>.json`. No engine change needed.
- `proc_poll_parse_line` early-returns on `MIDI Out:` lines because plugins like JE8086 spam one stdout line per outbound MIDI byte.

**Caveats:**
- Any `zynthian-ui` package upgrade overwrites engine patches; re-apply.
- Chains restored from a snapshot **don't pick up engine code changes** — remove and re-add the chain to instantiate a fresh processor.
- Bank P (JP-8000 Performances) / JD-800 Performance Mode are multitimbral and require a plugin-mode switch plus dual-channel PC dispatch — deferred.

## JE8086 specifics

The user's JE8086 plugin instance runs **JP-8000 firmware**, not JD-800. Evidence:
- `/root/.config/TheUsualSuspects/JE8086/readme.txt` says "JP-8000 Software Update Procedure".
- `SUM.TXT` has JP-8000 ROM block checksums; `_00001.MID`..`_00008.MID` are JP-8000 software-update SysEx.
- The "JD-4 VER1.00 '96" header that earlier notes captured was misleading — JE8086 is a multi-emulator; whatever ROM is loaded determines the patch layout.

**JP-8000 patch layout:** 128 patches = A1-1..A8-8 (PC 0–63) + B1-1..B8-8 (PC 64–127). MIDI selection requires **Bank Select MSB=0, LSB=0 (A) or LSB=1 (B)** then PC 0–63 within the bank. Raw PC alone won't reach Bank B.

**Where state lives:**
- `/zynthian/zynthian-my-data/presets/lv2/JE8086_Factory.presets.lv2/` — 128 TTLs, `rdfs:label` set to real JP-8000 factory names (read off the plugin display by the user 2026-06-08).
- `/zynthian/config/jalv/presets_JE8086.json` — 16 banks (`Internal A1`..`Internal B8`), 8 presets each. `Internal A1` additionally has `(none)` prepended (url `""`). Each entry has `midi_bank_select: [0, lsb, pc%64]`.
- Backups: `JE8086_Factory.presets.lv2.bak-20260511-060930`, `presets_JE8086.json.bak-20260511-060930`, plus `*.bak-prenames-20260608-024924`.

**Verbatim quirks in JP-8000 names** (kept exactly as displayed): `A3-8 "Proflike Clavit"`, `A7-4 "Org/Rotary>Ribon"`, `B4-1 "Skreachea"` (distinct from Performance P1-3 "Skreachy"), `B7-6 "The Etruscan."` (trailing period intentional), `B8-5 "Cool-a little..."` (trailing ellipsis intentional).

**Mode preference:** WHOLE / single-sound only. The user does **not** want a dual Upper/Lower preset UI — out of scope unless re-asked.

**Auto-init on chain add:** Local patch to `add_processor()` in `zynthian_engine_jalv.py` makes JE8086 auto-load the preset labelled `init` (currently in bank `Internal A1`, URL `…/JE8086.presets.lv2/init.ttl`) every time a new JE8086 chain is created. Helper `_load_default_preset(processor, label)` is generic — gate it on more plugin names or change the label to extend. Snapshot restore is safe (snapshot's set_preset runs after add_processor and wins). Lost on `zynthian-ui` upgrade.

**Patch storage internals (legacy reference, for the old JD-800 firmware):** RAM dump `/root/.local/share/The Usual Suspects/JE8086/roms/ram_dump.bin` (262144 bytes), patch table at base `0x010090`, stride `0x180`, 16-char ASCII name at offset 0. Performance table at `0x016090`, stride `0x780`. Holds 11 named Performances. ROM `.MID` files are SysEx-wrapped firmware code, not user-readable names. **Note:** the on-disk `ram_dump.bin` is only flushed on graceful shutdown and stays stale (still had JD-800 names 3+ weeks after the May 11 firmware switch) — don't trust it for live names.

**Auto-extraction of patch names is blocked:**
- JE8086 stores names as LV2 Parameters (atom `patch:Get`/`patch:Set` protocol), not control ports → `jalv -p`, `controls`, `monitors` all blind to them.
- `save preset` dumps state as one opaque base64 `<…JE8086:StateString>` blob.
- ROM `.so` strings yield only generic UI text.
- Don't re-investigate cheap routes; either implement an LV2 atom round-trip host (hours of work) or ask the user to read names off the display.
- Tooling that's available if needed: `python3 jack` 0.5.4, `python3 mido` 1.1.24. Useful jalv flags: `-n NAME` (unique JACK client), `-i`, `-p`, `-c SYM=VAL`, `-l DIR`, `-s`, `-t`, `-x`.

## V5 button bindings

The V5 touchkeypad button labelled `CTRL\nPRSET` (touchkeypad index 2 → `zynswitch 6,P/R`, wiring profile entry `SWITCH_03`) has three press-duration actions in `/zynthian/config/wiring-profiles/v5:151-154`:

- **Short tap** → `CHAIN_CONTROL` (controller groups: MIDI Controllers, A1..A27, Global 1..6)
- **Bold press** (~½ sec) → `BANK_PRESET` (bank/preset list toggle)
- **Long press** (~1 sec+) → `PRESET_FAV` (favorites)

When the user says "I can't get back to the preset list after selecting a patch" — ask whether they're tapping or holding. The journal will show no `cuia_bank_preset called` line if they only tapped. To swap defaults: edit `UI_SHORT` ↔ `UI_BOLD` in the wiring profile (global).

## Chain Options refactor (2026-06-02)

`zynthian-ui` commit `0aceb88f` moved "Insert new chain" out of Chain Options into Main Menu as **"Add Chain"** (tile, icon `add_chain.png`, wired to `cuia_add_chain`). `cuia_add_chain` (`zynthian_gui.py:1694`) inserts after `get_active_chain_index() + 1` — functionally identical to the old "Insert new chain".

Also added: a **"Clean"** tile that opens a grid for clean chains/sequences/all.

Removed helpers from Chain Options: `remove_cb`, `remove_chains`, `remove_all_confirmed`, `remove_chains_confirmed`, `remove_sequences_confirmed`, `insert_chain`.

If the user reports a missing Chain Options entry after an update, check this commit first.

## Known bug: CUIA worker / Tk deadlock

2026-06-09 hit a hard UI freeze (touch + encoders + switches dead, terminal still worked). Diagnosed with `py-spy dump --pid $(pgrep -f zynthian_main.py)`:

- **MainThread**: inside Tk `on_release` → `switch_select` → `cuia_power` → `power` → `show_screen` (`zynthian_gui.py:649`). Blocked on a `threading.Lock` held by the CUIA worker.
- **CUIA thread**: inside `cuia_thread_task` → `cuia_add_chain` → `show_screen` → `build_view` (`zynthian_gui_add_chain.py:96`) → `_draw_nodes` → `get_icon` → `PIL.ImageTk.PhotoImage.__init__`. Blocked waiting for the Tcl interpreter mutex.
- Status and zynpot threads also wedged trying to call Tk from non-main threads.

**Diagnosis:** CUIA worker calls into Tk / `PIL.ImageTk` directly from a non-main thread. When a main-thread Tk event handler then takes a lock the CUIA worker holds, both sides deadlock. ~8% CPU after freeze is JACK callback threads, not progress.

**Recovery:** `systemctl restart zynthian`.

**Upstream issue filed:** https://github.com/zynthian/zynthian-issue-tracking/issues/1689 — GitHub will email the user on any status change.

**Architectural fix (for upstream):** CUIA worker should marshal Tk calls back to the main thread via `widget.after_idle(...)` instead of calling `build_view` / `PhotoImage` directly. Same applies to Status, zynpot, and Multitouch threads.

## Known bug FIXED: layered-snapshot preset hijack (#1705)

2026-06-29. A 4-layer snapshot (JE8086 + LinuxSampler + Pianoteq + FluidSynth, all on MIDI ch 1) restored with the **FluidSynth layer playing GM Violin/strings** instead of its "FM Piano" SF2, while the UI showed the correct name. Manual re-pick fixed it until the next snapshot load.

**Cause (two parts):**
1. JE8086 selects "Tiny bells" via MIDI Bank Select `[0,1]` + PC 40, which was sent **on the MIDI channel** (global) → every chain on ch 1 received it. `FM Piano.sf2` has no bank 1 → FluidSynth GM-substituted → program 40 = Violin. Confirmed via fluidsynth `channels -verbose`: `Instrument not found [bank=1 prog=40], substituted` + `chan 0 ... preset 40, Violin`.
2. Snapshot restore never re-invoked `set_preset` (cmp_presets short-circuit), so firmware-emulator + FluidSynth chains started on defaults.

**Fix (in kit, 4 patched files):** route the preset Bank Select + PC through the chain's own `zmop_index` (`zmop_send_program_change`/`zmop_send_ccontrol_change`) so it can't leak to layer-mates; and re-fire `set_preset(force_set_engine=True)` after restore for engines flagged `needs_set_preset_after_restore`. See the firmware-emulator section above.

**Dead end (don't repeat):** unloading + reloading the FluidSynth soundfont in the post-restore loop "worked" only because verbose logging added delay — a pexpect race, not a real fix. The font is already loaded by `set_bank_by_info` during restore; no reload is needed.

**Upstream issue filed:** https://github.com/zynthian/zynthian-issue-tracking/issues/1705 — found while running the custom JE8086 integration (`JE8086.md`). GitHub emails the user on status changes.

## Tooling installed on this Zynthian

- **`py-spy`** in `/zynthian/venv/bin/py-spy` (2.8 MB, manylinux2014_aarch64 wheel, installed 2026-06-09 via `/zynthian/venv/bin/pip install py-spy`). Single binary, gives Python line-level stacks of a running process without restarting it. Much lighter than `python3-dbg` + gdb's `py-bt`.
- **`gh`** CLI v2.23 (apt, installed 2026-06-09), authenticated as `smatheusale`.
- `python3 jack` 0.5.4, `python3 mido` 1.1.24 — installed system-wide for any LV2/JACK scripting.

## Side observation

Boot log error: `error: failed to open file /zynthian/zynthian-my-data/presets/lv2/esp_jit.log/manifest.ttl (Not a directory)`. There's a 0-byte file `esp_jit.log` being created in the LV2 presets dir at every boot (likely an LV2 plugin writing a JIT log to its CWD). Causes lilv to log an error on every world-load but is otherwise harmless. Deleting it is a non-fix; it regenerates next boot. To find the writer: `inotifywait -m -r /zynthian/zynthian-my-data/presets/lv2/` during boot, or `lsof | grep esp_jit`.
