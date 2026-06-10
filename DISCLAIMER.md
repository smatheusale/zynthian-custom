# Legal disclaimer

## Third-party plugin

This repository provides **configuration and customization** for the
**JE8086** LV2 plugin published by **The Usual Suspects**
([https://theusualsuspects.lv2](https://theusualsuspects.lv2)). The plugin
itself is **not** included or redistributed here — you must download and
install it from the vendor on your own.

Nothing in this repository is endorsed by, affiliated with, or supported by
The Usual Suspects.

## Trademarks

- **Roland**, **JP-8000**, **JD-800**, **MKS-80**, **TB-303**, **GR-300**,
  **Juno**, and related product names are trademarks or registered
  trademarks of **Roland Corporation**. Use of these names in this
  repository is purely descriptive — to indicate which patch slots of the
  emulated instrument the presets correspond to — and does **not** imply any
  endorsement by or affiliation with Roland.
- **AKS**, **VOX**, **Mini Moog**, and other instrument names that appear in
  preset labels are trademarks of their respective owners and are also used
  descriptively.
- **Zynthian** is a trademark of the Zynthian project
  ([zynthian.org](https://zynthian.org)).

## Factory preset names

The 128 factory patch labels (e.g. "Chariots", "Glass Columns",
"Velo Decay Bass", …) are the original JP-8000 factory program names.
They are reproduced here purely as identifiers so the Zynthian UI shows the
same labels the user would see on the original hardware. No claim of
originality or ownership over these names is made.

## State data

The `StateString` blobs inside the preset TTL files are produced by saving
state from a user-installed JE8086 plugin instance. They are not the work of
the plugin vendor and contain only a snapshot of editable plugin parameters
(envelope shapes, oscillator settings, etc.) that the user is free to
re-create.

## GPL components

The Zynthian engine patch (`engine/zynthian_engine_jalv.patch` and
`engine/zynthian_engine_jalv.full.py`) is a derivative of `zynthian-ui` and
is distributed under **GNU GPL-3.0**. See `LICENSE` and the upstream project
at <https://github.com/zynthian/zynthian-ui>.

## No warranty

Everything here is provided **as is, with no warranty of any kind**. Loading
the wrong preset cache or running the engine patch on the wrong
`zynthian-ui` revision can break preset switching. Back up your
`/zynthian/config/jalv/presets_JE8086.json` and any `~/.local/share/The
Usual Suspects/JE8086/config/JE8086.xml` before applying anything in this
repository.

## Contact

- Maintainer: **@smatheusale** on Instagram
- Repository: <https://github.com/smatheusale/zynthian-custom>
