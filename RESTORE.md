# Zynthian customization restore kit

Everything here is what we've changed beyond a stock Zynthian install. The kit
lives at `/zynthian/zynthian-my-data/zynthian-custom/` — the user-data
partition, which survives Zynthian package upgrades and is the directory you'd
back up before a reformat.

`baseline.txt` records the ZynthianOS version, zynthian-ui git commit, and
date at which the customizations were captured. If a later install drifts
far from that baseline, prefer the manual patch route over `git apply`.

## What's customized

| What | Where it lives in stock Zynthian | Reason |
|---|---|---|
| Engine patch | `/zynthian/zynthian-ui/zyngine/zynthian_engine_jalv.py` | (a) Firmware-emulator MIDI-PC dispatch (JE8086 / NodalRed2x / VirtualJV state-restore doesn't work at runtime; we send Bank Select + PC instead). (b) JE8086 auto-loads a preset labelled `init` on every chain add. |
| JE8086 factory bundle | `/zynthian/zynthian-my-data/presets/lv2/JE8086_Factory.presets.lv2/` | 128 TTLs labelled with the real JP-8000 factory patch names (A1-1..B8-8), read off the plugin display 2026-06-08. |
| JE8086 user bundle | `/zynthian/zynthian-my-data/presets/lv2/JE8086.presets.lv2/` | Holds the `init` preset that auto-loads on chain add. |
| Preset cache | `/zynthian/config/jalv/presets_JE8086.json` | 16 banks × 8 entries with `midi_bank_select: [0, lsb, pc]` populated and `(none)` prepended to bank `Internal A1`. Engine reads this to know what MIDI to send. |
| Tooling | `/zynthian/venv/bin/py-spy`, `/usr/bin/gh` | `py-spy` (pip in venv) for diagnosing UI freezes; `gh` (apt) for filing issues. |

## How to restore after a reformat or fresh install

**Prerequisite:** install the JE8086 LV2 plugin from The Usual Suspects
*before* restoring. Without it, the bundles/cache reference a nonexistent
plugin. (`/usr/local/lib/lv2/JE8086.lv2/` is the install target.)

Then run:

```bash
cd /zynthian/zynthian-my-data/zynthian-custom
./restore.sh
```

It will:

1. Try `git apply` of `engine/zynthian_engine_jalv.patch` against the current
   `zynthian-ui`. If it applies cleanly, the engine patch is restored.
2. If the patch fails (upstream rewrote the same lines), it stops and tells
   you to apply manually — see "Manual engine re-apply" below.
3. Copy `cache/presets_JE8086.json` into place.
4. Copy `bundles/JE8086.presets.lv2/` and `bundles/JE8086_Factory.presets.lv2/`
   into `/zynthian/zynthian-my-data/presets/lv2/`.
5. Reinstall `py-spy` and `gh` if missing.
6. Restart `zynthian.service`.

Then run `./verify.sh` to confirm everything is in place.

## Manual engine re-apply (if `git apply` fails)

The patch makes three changes to `zynthian_engine_jalv.py`. If upstream has
rewritten that file, find these by symbol name and re-apply:

### Change 1 — `get_preset_list` surfaces MIDI info

The preset tuples that `get_preset_list` returns must put MIDI info in slot 1.
Replace the per-info build line with:

```python
midi_info = info.get('midi_bank_select') or info.get('midi_pc')
preset_list.append([info['url'], midi_info, title, bank[0]])
```

### Change 2 — `set_preset` dispatches MIDI for firmware emulators

`set_preset` should call the LV2 preset URI as before, then dispatch MIDI:

```python
def set_preset(self, processor, preset, preload=False):
    if not preset[0]:
        return
    self.proc_cmd(f"preset {preset[0]}")
    midi_info = preset[1]
    if midi_info is not None:
        chan = processor.get_midi_chan()
        self._dispatch_firmware_midi(chan, midi_info)
        # Re-dispatch after a delay so snapshot restore lands AFTER
        # zynautoconnect wires the chain's MIDI and jalv is fully up.
        from threading import Timer
        Timer(1.5, self._dispatch_firmware_midi, args=(chan, midi_info)).start()
    return True

def _dispatch_firmware_midi(self, chan, midi_info):
    try:
        lib_zyncore.ui_send_ccontrol_change(chan, 120, 0)  # All Sound Off
        lib_zyncore.ui_send_ccontrol_change(chan, 123, 0)  # All Notes Off
    except Exception as e:
        logging.warning(f"All-Sound-Off / All-Notes-Off failed: {e}")
    try:
        if isinstance(midi_info, (list, tuple)) and len(midi_info) == 3:
            self.state_manager.zynmidi.set_midi_preset(
                chan, midi_info[0], midi_info[1], midi_info[2])
        elif isinstance(midi_info, int):
            self.state_manager.zynmidi.set_midi_prg(chan, midi_info)
    except Exception as e:
        logging.warning(f"Firmware-emulator MIDI preset dispatch failed: {e}")
```

### Change 3 — JE8086 auto-init on chain add

```python
def add_processor(self, processor):
    self.set_midi_chan(processor)
    super().add_processor(processor)
    if self.plugin_name == "JE8086":
        self._load_default_preset(processor, "init")

def _load_default_preset(self, processor, label):
    try:
        for bank_label, info in self.preset_info.items():
            for p in info['presets']:
                if p.get('label', '').strip().lower() == label.lower():
                    midi_info = p.get('midi_bank_select') or p.get('midi_pc')
                    self.set_preset(processor, [p['url'], midi_info, p['label'], bank_label])
                    return
        logging.warning(f"{self.plugin_name}: default preset {label!r} not found")
    except Exception as e:
        logging.error(f"{self.plugin_name}: default preset load failed: {e}")
```

### Change 4 — silence `MIDI Out:` log spam (if not already upstream)

In `proc_poll_parse_line`, early-return on `MIDI Out:` lines because firmware
emulators emit one stdout line per outbound MIDI byte and saturate the
poll thread. Look for the line-parsing dispatch and add:

```python
if line.startswith("MIDI Out:"):
    return
```

at the top.

## Verifying

`./verify.sh` runs these checks:

- `zynthian_engine_jalv.py` contains the four edits (greps for marker symbols).
- The preset cache has 128 entries with `midi_bank_select` populated.
- The factory bundle has all 128 TTLs.
- The `init.ttl` user preset exists and is referenced from its manifest.
- `py-spy` and `gh` are present.
- `systemctl is-active zynthian` is `active`.

## Backing this kit up off-device

Before a reformat, copy the whole directory off the Pi:

```bash
# from another machine:
rsync -avh root@zynthian.local:/zynthian/zynthian-my-data/zynthian-custom/ ./zynthian-custom-backup/
```

Or commit it to a private git repo. The directory is ~600 KB.

## Refreshing the kit after future edits

After making more changes to any of these files, re-snapshot the kit:

```bash
cd /zynthian/zynthian-my-data/zynthian-custom
./refresh.sh
```

That re-runs the git diff against the engine, copies the cache and bundles
back into this directory, and updates `baseline.txt`. Commit the result if
you're versioning the kit.
