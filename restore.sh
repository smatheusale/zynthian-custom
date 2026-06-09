#!/bin/bash
# Restore Zynthian customizations onto a fresh install.
# Run as root. Prerequisite: JE8086 LV2 plugin must already be installed at
# /usr/local/lib/lv2/JE8086.lv2/ — restoring presets without the plugin is harmless
# but the bundles won't appear in the UI.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "==> Restoring from $HERE"

# 1. Engine patch
echo "==> Patching zynthian-ui engine"
cd /zynthian/zynthian-ui
if git apply --check "$HERE/engine/zynthian_engine_jalv.patch" 2>/dev/null; then
    git apply "$HERE/engine/zynthian_engine_jalv.patch"
    echo "    patch applied cleanly"
else
    echo "    !! git apply failed — upstream rewrote the file."
    echo "    !! See RESTORE.md → 'Manual engine re-apply' section."
    echo "    !! Reference full known-good copy: $HERE/engine/zynthian_engine_jalv.full.py"
    exit 2
fi

# 2. Preset cache
echo "==> Restoring preset cache"
mkdir -p /zynthian/config/jalv
cp "$HERE/cache/presets_JE8086.json" /zynthian/config/jalv/

# 3. LV2 bundles
echo "==> Restoring LV2 user bundles"
mkdir -p /zynthian/zynthian-my-data/presets/lv2
cp -r "$HERE/bundles/JE8086.presets.lv2" /zynthian/zynthian-my-data/presets/lv2/
cp -r "$HERE/bundles/JE8086_Factory.presets.lv2" /zynthian/zynthian-my-data/presets/lv2/

# 4. Tooling
if [[ ! -x /zynthian/venv/bin/py-spy ]]; then
    echo "==> Installing py-spy in zynthian venv"
    /zynthian/venv/bin/pip install py-spy
fi
if ! command -v gh >/dev/null 2>&1; then
    echo "==> Installing gh CLI"
    apt-get install -y gh
fi

# 5. Restart service
echo "==> Restarting zynthian.service"
systemctl restart zynthian
sleep 3
systemctl is-active zynthian >/dev/null && echo "    zynthian is active"

echo "==> Done. Run ./verify.sh to confirm."
