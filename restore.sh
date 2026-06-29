#!/bin/bash
# Restore Zynthian customizations onto a fresh install.
# Run as root. Prerequisite: JE8086 LV2 plugin must already be installed at
# /usr/local/lib/lv2/JE8086.lv2/ — restoring presets without the plugin is harmless
# but the bundles won't appear in the UI.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "==> Restoring from $HERE"

# 1. Engine patches
echo "==> Patching zynthian-ui engine"
cd /zynthian/zynthian-ui
ENGINE_PATCHES=(
    zynthian_engine_jalv
    zynthian_engine
    zynthian_engine_fluidsynth
    zynthian_state_manager
)
for base in "${ENGINE_PATCHES[@]}"; do
    patch="$HERE/engine/${base}.patch"
    [ -s "$patch" ] || continue  # skip empty patches
    if git apply --check "$patch" 2>/dev/null; then
        git apply "$patch"
        echo "    $base patch applied cleanly"
    else
        echo "    !! git apply failed for $base — upstream rewrote the file."
        echo "    !! See RESTORE.md → 'Manual engine re-apply' section."
        echo "    !! Reference full known-good copy: $HERE/engine/${base}.full.py"
        exit 2
    fi
done

# 2. Preset cache
echo "==> Restoring preset cache"
mkdir -p /zynthian/config/jalv
cp "$HERE/cache/presets_JE8086.json" /zynthian/config/jalv/

# 3. LV2 bundles
echo "==> Restoring LV2 user bundles"
mkdir -p /zynthian/zynthian-my-data/presets/lv2
cp -r "$HERE/bundles/JE8086.presets.lv2" /zynthian/zynthian-my-data/presets/lv2/
cp -r "$HERE/bundles/JE8086_Factory.presets.lv2" /zynthian/zynthian-my-data/presets/lv2/

# 4. System units (JACK buffer size etc.)
if [[ -f "$HERE/system/jack2.service" ]]; then
    echo "==> Restoring /etc/systemd/system/jack2.service (JACK -p 256 buffer)"
    cp "$HERE/system/jack2.service" /etc/systemd/system/jack2.service
    systemctl daemon-reload
fi
if [[ -f "$HERE/system/zynthian_envars.sh" ]]; then
    echo "==> Restoring /zynthian/config/zynthian_envars.sh"
    cp "$HERE/system/zynthian_envars.sh" /zynthian/config/zynthian_envars.sh
fi

# 5. Tooling
if [[ ! -x /zynthian/venv/bin/py-spy ]]; then
    echo "==> Installing py-spy in zynthian venv"
    /zynthian/venv/bin/pip install py-spy
fi
if ! command -v gh >/dev/null 2>&1; then
    echo "==> Installing gh CLI"
    apt-get install -y gh
fi

# 6. Restart service
echo "==> Restarting zynthian.service"
systemctl restart zynthian
sleep 3
systemctl is-active zynthian >/dev/null && echo "    zynthian is active"

echo "==> Done. Run ./verify.sh to confirm."
