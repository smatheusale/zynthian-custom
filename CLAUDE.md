# Claude — this is the Zynthian customization project

This repository is the durable home of every customization on the user's Zynthian (Raspberry Pi 5, V5 controller).

**Before doing anything**, read in order:
1. [`SKILL.md`](SKILL.md) — full working knowledge: user context, LV2 workflow, firmware-emulator patches, JE8086 specifics, V5 button bindings, known bugs, tooling.
2. [`RESTORE.md`](RESTORE.md) — restoration runbook for upgrades / reformats / fresh installs.
3. [`baseline.txt`](baseline.txt) — which zynthian-ui commit and ZynthianOS version this kit was captured against.

**If the user mentions "I updated Zynthian", "I formatted", "things broke after the upgrade", or "I'm on a new SD card":** open `RESTORE.md` first, then run `./restore.sh && ./verify.sh`.

**After any further customization in a session** (engine edits, new preset bundles, cache changes, tooling installs): prompt the user about refreshing the kit, then:
```bash
./refresh.sh
git add -A
git commit -m "<summary>"
git push
```

**This repository can be loaded as a Claude Desktop / Chrome Project knowledge source** — `SKILL.md` is the consolidated single-file reference designed for that purpose.
