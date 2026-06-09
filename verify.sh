#!/bin/bash
# Verify Zynthian customizations are in place.

PASS=0; FAIL=0
ok()   { echo "  [ok]  $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

ENG=/zynthian/zynthian-ui/zyngine/zynthian_engine_jalv.py
CACHE=/zynthian/config/jalv/presets_JE8086.json
BUNDLE_FAC=/zynthian/zynthian-my-data/presets/lv2/JE8086_Factory.presets.lv2
BUNDLE_USER=/zynthian/zynthian-my-data/presets/lv2/JE8086.presets.lv2

echo "==> Engine patch"
grep -q "_dispatch_firmware_midi" "$ENG" && ok "MIDI dispatch helper present" || fail "MIDI dispatch helper missing"
grep -q "_load_default_preset"   "$ENG" && ok "auto-init helper present"    || fail "auto-init helper missing"
grep -q 'midi_bank_select'       "$ENG" && ok "get_preset_list surfaces MIDI info" || fail "get_preset_list not patched"

echo "==> Preset cache"
if [[ -f $CACHE ]]; then
    N=$(python3 -c "import json; d=json.load(open('$CACHE')); print(sum(len(b['presets']) for b in d.values()))")
    if [[ $N -ge 128 ]]; then ok "cache has $N preset entries"; else fail "cache only has $N preset entries"; fi
    python3 -c "import json; d=json.load(open('$CACHE')); first=list(d.values())[0]['presets']; assert any(p.get('label')=='(none)' for p in first)" 2>/dev/null \
        && ok "(none) entry prepended"  || fail "(none) entry missing"
else
    fail "cache file missing"
fi

echo "==> LV2 bundles"
[[ -d $BUNDLE_FAC ]] && ok "factory bundle present" || fail "factory bundle missing"
N=$(ls "$BUNDLE_FAC"/JE8086-*.ttl 2>/dev/null | wc -l)
[[ $N -ge 128 ]] && ok "factory bundle has $N TTLs" || fail "factory bundle only has $N TTLs"
[[ -f $BUNDLE_USER/init.ttl ]] && ok "init.ttl preset present" || fail "init.ttl missing"

echo "==> Tooling"
[[ -x /zynthian/venv/bin/py-spy ]] && ok "py-spy installed" || fail "py-spy missing"
command -v gh >/dev/null 2>&1 && ok "gh installed" || fail "gh missing"

echo "==> Service"
systemctl is-active zynthian >/dev/null 2>&1 && ok "zynthian.service active" || fail "zynthian.service not active"

echo
echo "Passed: $PASS   Failed: $FAIL"
[[ $FAIL -eq 0 ]]
