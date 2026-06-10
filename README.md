# zynthian-custom

Personal customizations for my [Zynthian](https://zynthian.org) (Raspberry Pi 5, V5 controller). Self-contained restore kit so any reformat or upstream upgrade is a one-command recovery.

By **[@smatheusale](https://instagram.com/smatheusale)** on Instagram. Code is
MIT-licensed, the engine patch derives from `zynthian-ui` (GPL-3.0). See
[`LICENSE`](LICENSE) and [`DISCLAIMER.md`](DISCLAIMER.md).

➡ **Looking for the JE8086 / Roland JP-8000 writeup?** See
[`JE8086.md`](JE8086.md) for the full how-to.

See [`RESTORE.md`](RESTORE.md) for the full runbook.

## Quick start (fresh install)

1. Install the JE8086 LV2 plugin (vendor: The Usual Suspects) at `/usr/local/lib/lv2/JE8086.lv2/`.
2. Clone this repo into the user-data partition:

   ```bash
   git clone https://github.com/smatheusale/zynthian-custom.git /zynthian/zynthian-my-data/zynthian-custom
   cd /zynthian/zynthian-my-data/zynthian-custom
   ./restore.sh
   ./verify.sh
   ```

## What's in here

- Engine patch for `zynthian-ui` that adds MIDI-PC dispatch for firmware-emulator LV2 plugins (JE8086 / NodalRed2x / VirtualJV) and auto-loads an "init" preset on every JE8086 chain add.
- 128-patch JP-8000 factory bundle for JE8086 with the real patch names.
- User preset bundle holding the `init` preset.
- Matching jalv preset cache.
- `restore.sh` / `verify.sh` / `refresh.sh` automation.
