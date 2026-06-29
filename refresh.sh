#!/bin/bash
# Re-snapshot current customizations into this kit.
# Run after making more changes to the engine, cache, or bundles.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "==> Refreshing kit at $HERE"

cd /zynthian/zynthian-ui
# All patched zynthian-ui source files. Add new ones here as customizations grow.
ENGINE_FILES=(
    zyngine/zynthian_engine_jalv.py
    zyngine/zynthian_engine.py
    zyngine/zynthian_engine_fluidsynth.py
    zyngine/zynthian_state_manager.py
)
for f in "${ENGINE_FILES[@]}"; do
    base="$(basename "$f" .py)"
    git diff HEAD -- "$f" > "$HERE/engine/${base}.patch"
    cp "/zynthian/zynthian-ui/$f" "$HERE/engine/${base}.full.py"
done

cp /zynthian/config/jalv/presets_JE8086.json "$HERE/cache/"

mkdir -p "$HERE/system"
cp /etc/systemd/system/jack2.service "$HERE/system/jack2.service"
cp /zynthian/config/zynthian_envars.sh "$HERE/system/zynthian_envars.sh"

rm -rf "$HERE/bundles/JE8086.presets.lv2" "$HERE/bundles/JE8086_Factory.presets.lv2"
cp -r /zynthian/zynthian-my-data/presets/lv2/JE8086.presets.lv2 "$HERE/bundles/"
cp -r /zynthian/zynthian-my-data/presets/lv2/JE8086_Factory.presets.lv2 "$HERE/bundles/"

cat > "$HERE/baseline.txt" <<EOF
# Customization baseline — what we patched against
captured: $(date -Iseconds)
host: $(hostname)
zynthianos_version: $(cat /zynthian/build_version.txt 2>/dev/null || echo unknown)
zynthian_ui_commit: $(git -C /zynthian/zynthian-ui rev-parse HEAD)
zynthian_ui_branch: $(git -C /zynthian/zynthian-ui rev-parse --abbrev-ref HEAD)
python: $(python3 --version)
kernel: $(uname -r)
EOF

echo "==> Kit refreshed."
