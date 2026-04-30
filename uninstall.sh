#!/usr/bin/env bash
# uninstall.sh - Remove GLaDOS TTS models, venv, audio cache, and global registration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/plugin"
TTS_DIR="${PLUGIN_DIR}/tts"

echo "GLaDOS TTS Plugin - Uninstall"
echo ""

# Stop server if running
"${PLUGIN_DIR}/bin/stop.sh" 2>/dev/null || true

# --- Remove global registration ---
echo "Removing global registration..."

unregister_cortex_code() {
    local config_dir="$HOME/.snowflake/cortex"
    local settings_file="${config_dir}/settings.json"
    local skills_dir="${config_dir}/skills/glados"

    # Remove skill directory
    if [[ -d "${skills_dir}" ]]; then
        rm -rf "${skills_dir}"
        echo "  ✓ Removed skill from ${skills_dir}"
    fi

    # Remove hooks from settings.json
    if [[ -f "${settings_file}" ]]; then
        python3 << MERGE_EOF
import json

settings_file = "${settings_file}"
plugin_dir = "${PLUGIN_DIR}"

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
modified = False

serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
speak_cmd = f"bash {plugin_dir}/bin/speak.sh"

# Remove SessionStart hooks matching our command
session_start = hooks.get('SessionStart', [])
new_session_start = [
    entry for entry in session_start
    if not any(h.get('command', '') == serve_cmd for h in entry.get('hooks', []))
]
if len(new_session_start) != len(session_start):
    modified = True
    if new_session_start:
        hooks['SessionStart'] = new_session_start
    else:
        hooks.pop('SessionStart', None)

# Remove Stop hooks matching our command
stop = hooks.get('Stop', [])
new_stop = [
    entry for entry in stop
    if not any(h.get('command', '') == speak_cmd for h in entry.get('hooks', []))
]
if len(new_stop) != len(stop):
    modified = True
    if new_stop:
        hooks['Stop'] = new_stop
    else:
        hooks.pop('Stop', None)

if not hooks:
    settings.pop('hooks', None)

if modified:
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print("  ✓ Hooks removed from " + settings_file)
else:
    print("  - No hooks to remove in " + settings_file)
MERGE_EOF
    fi
}

unregister_claude_code() {
    local config_dir="$HOME/.claude"
    local settings_file="${config_dir}/settings.json"
    local skills_dir="${config_dir}/skills/glados"

    # Remove skill directory
    if [[ -d "${skills_dir}" ]]; then
        rm -rf "${skills_dir}"
        echo "  ✓ Removed skill from ${skills_dir}"
    fi

    if [[ ! -f "${settings_file}" ]]; then
        return 0
    fi

    python3 << MERGE_EOF
import json

settings_file = "${settings_file}"
plugin_dir = "${PLUGIN_DIR}"

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
modified = False

serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
speak_cmd = f"bash {plugin_dir}/bin/speak.sh"

session_start = hooks.get('SessionStart', [])
new_session_start = [
    entry for entry in session_start
    if not any(h.get('command', '') == serve_cmd for h in entry.get('hooks', []))
]
if len(new_session_start) != len(session_start):
    modified = True
    if new_session_start:
        hooks['SessionStart'] = new_session_start
    else:
        hooks.pop('SessionStart', None)

stop = hooks.get('Stop', [])
new_stop = [
    entry for entry in stop
    if not any(h.get('command', '') == speak_cmd for h in entry.get('hooks', []))
]
if len(new_stop) != len(stop):
    modified = True
    if new_stop:
        hooks['Stop'] = new_stop
    else:
        hooks.pop('Stop', None)

if not hooks:
    settings.pop('hooks', None)

if modified:
    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    print("  ✓ Hooks removed from " + settings_file)
else:
    print("  - No hooks to remove in " + settings_file)
MERGE_EOF
}

unregister_cortex_code
unregister_claude_code

# --- Remove models ---
if [[ -d "${TTS_DIR}/models" ]]; then
    echo "Removing models..."
    rm -rf "${TTS_DIR}/models"
    mkdir -p "${TTS_DIR}/models/emb"
    echo "  ✓ Models removed"
fi

# --- Remove venv ---
if [[ -d "${TTS_DIR}/.venv" ]]; then
    echo "Removing virtual environment..."
    rm -rf "${TTS_DIR}/.venv"
    echo "  ✓ Venv removed"
fi

# --- Remove audio cache ---
if [[ -d "${TTS_DIR}/audio" ]]; then
    echo "Removing audio cache..."
    rm -rf "${TTS_DIR}/audio"
    echo "  ✓ Audio cache removed"
fi

# Remove server runtime files
rm -f "${TTS_DIR}/server.log" "${TTS_DIR}/server.pid"

echo ""
echo "Uninstall complete. Plugin source code remains — models, dependencies, and"
echo "global registration have been removed. Run install.sh to re-install."
