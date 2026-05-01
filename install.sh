#!/usr/bin/env bash
# install.sh - Install GLaDOS TTS plugin dependencies, models, and register globally
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/plugin"
TTS_DIR="${PLUGIN_DIR}/tts"
MODELS_DIR="${TTS_DIR}/models"
VENV_DIR="${TTS_DIR}/.venv"

echo "======================================"
echo " GLaDOS TTS Plugin - Installation"
echo "======================================"
echo ""

# --- Python venv setup ---
echo "[1/4] Setting up Python virtual environment..."

if [[ ! -d "${VENV_DIR}" ]]; then
    python3 -m venv "${VENV_DIR}"
fi

source "${VENV_DIR}/bin/activate"
pip install --upgrade pip -q --index-url https://pypi.org/simple/
pip install -r "${TTS_DIR}/requirements.txt" -q --index-url https://pypi.org/simple/

echo "  ✓ Dependencies installed"

# --- Model download ---
echo ""
echo "[2/4] Downloading GLaDOS TTS models (~260MB)..."
echo "      Source: https://github.com/R2D2FISH/glados-tts"
echo ""

mkdir -p "${MODELS_DIR}/emb"

# Model URLs (GitHub raw files from R2D2FISH/glados-tts)
GLADOS_MODEL_URL="https://github.com/R2D2FISH/glados-tts/raw/main/models/glados-new.pt"
VOCODER_URL="https://github.com/R2D2FISH/glados-tts/raw/main/models/vocoder-gpu.pt"
EMB_URL="https://github.com/R2D2FISH/glados-tts/raw/main/models/emb/glados_p2.pt"
PHONEMIZER_URL="https://github.com/R2D2FISH/glados-tts/raw/main/models/en_us_cmudict_ipa_forward.pt"

download_model() {
    local url="$1"
    local dest="$2"
    local name="$3"

    if [[ -f "${dest}" ]]; then
        echo "  ✓ ${name} (already exists)"
        return 0
    fi

    echo "  ↓ Downloading ${name}..."
    if curl -fSL --progress-bar "${url}" -o "${dest}"; then
        echo "  ✓ ${name}"
    else
        echo "  ✗ Failed to download ${name}" >&2
        echo "    Try manually: curl -L '${url}' -o '${dest}'" >&2
        return 1
    fi
}

download_model "${GLADOS_MODEL_URL}" "${MODELS_DIR}/glados-new.pt" "Forward Tacotron (glados-new.pt)"
download_model "${VOCODER_URL}" "${MODELS_DIR}/vocoder-gpu.pt" "HiFiGAN Vocoder (vocoder-gpu.pt)"
download_model "${EMB_URL}" "${MODELS_DIR}/emb/glados_p2.pt" "Speaker Embedding (glados_p2.pt)"
download_model "${PHONEMIZER_URL}" "${MODELS_DIR}/en_us_cmudict_ipa_forward.pt" "Phonemizer Model (en_us_cmudict_ipa_forward.pt)"

# --- State directory ---
echo ""
echo "[3/5] Creating runtime state directory..."

# Resolve GLADOS_STATE_DIR (same logic as plugin/lib/state-dir.sh)
if [[ -n "${GLADOS_STATE_DIR:-}" ]]; then
    :
elif [[ -n "${CORTEX_SESSION_ID:-}" ]]; then
    GLADOS_STATE_DIR="${HOME}/.snowflake/cortex/cache/glados"
elif [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    GLADOS_STATE_DIR="${HOME}/.claude/cache/glados"
else
    GLADOS_STATE_DIR="${HOME}/.local/state/glados-tts"
fi

mkdir -p "${GLADOS_STATE_DIR}/sessions"
mkdir -p "${GLADOS_STATE_DIR}/audio"
echo "  ✓ State directory: ${GLADOS_STATE_DIR}"

# --- Global registration ---
echo ""
echo "[4/5] Registering plugin globally..."

register_cortex_code() {
    local config_dir="$HOME/.snowflake/cortex"
    local settings_file="${config_dir}/settings.json"
    local skills_dir="${config_dir}/skills/glados"

    # Install skill files (substitute __PLUGIN_DIR__ placeholder with actual path)
    mkdir -p "${skills_dir}"
    for skill_file in "${PLUGIN_DIR}/skills/glados/"*.md; do
        sed "s|__PLUGIN_DIR__|${PLUGIN_DIR}|g" "${skill_file}" > "${skills_dir}/$(basename "${skill_file}")"
    done
    echo "  ✓ GLaDOS skill installed to ${skills_dir}"

    # Register hooks in settings.json (Stop + SessionEnd only; no SessionStart)
    if [[ ! -f "${settings_file}" ]]; then
        mkdir -p "${config_dir}"
        cat > "${settings_file}" << SETTINGS_EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/speak.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/session_end.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
        echo "  ✓ Created ${settings_file} with hooks"
    else
        python3 << MERGE_EOF
import json, sys

settings_file = "${settings_file}"
plugin_dir = "${PLUGIN_DIR}"

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# Remove old SessionStart hook if present (migration from previous install)
serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
if 'SessionStart' in hooks:
    hooks['SessionStart'] = [
        entry for entry in hooks['SessionStart']
        if not any(h.get('command', '') == serve_cmd for h in entry.get('hooks', []))
    ]
    if not hooks['SessionStart']:
        del hooks['SessionStart']

# Stop hook
speak_cmd = f"bash {plugin_dir}/bin/speak.sh"
stop = hooks.get('Stop', [])
already_has_speak = any(
    h.get('command', '') == speak_cmd
    for entry in stop
    for h in entry.get('hooks', [])
)
if not already_has_speak:
    stop.append({
        "hooks": [{"type": "command", "command": speak_cmd, "timeout": 30}]
    })
    hooks['Stop'] = stop

# SessionEnd hook
session_end_cmd = f"bash {plugin_dir}/bin/session_end.sh"
session_end = hooks.get('SessionEnd', [])
already_has_end = any(
    h.get('command', '') == session_end_cmd
    for entry in session_end
    for h in entry.get('hooks', [])
)
if not already_has_end:
    session_end.append({
        "hooks": [{"type": "command", "command": session_end_cmd, "timeout": 10}]
    })
    hooks['SessionEnd'] = session_end

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print("  ✓ Hooks registered in " + settings_file)
MERGE_EOF
    fi
}

register_claude_code() {
    local config_dir="$HOME/.claude"
    local settings_file="${config_dir}/settings.json"

    if [[ ! -d "${config_dir}" ]]; then
        echo "  - Claude Code not detected (no ~/.claude), skipping"
        return 0
    fi

    if [[ ! -f "${settings_file}" ]]; then
        cat > "${settings_file}" << SETTINGS_EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/speak.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/session_end.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
        echo "  ✓ Created ${settings_file} with hooks"
    else
        python3 << MERGE_EOF
import json

settings_file = "${settings_file}"
plugin_dir = "${PLUGIN_DIR}"

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# Remove old SessionStart hook if present (migration)
serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
if 'SessionStart' in hooks:
    hooks['SessionStart'] = [
        entry for entry in hooks['SessionStart']
        if not any(h.get('command', '') == serve_cmd for h in entry.get('hooks', []))
    ]
    if not hooks['SessionStart']:
        del hooks['SessionStart']

# Stop hook
speak_cmd = f"bash {plugin_dir}/bin/speak.sh"
stop = hooks.get('Stop', [])
already_has_speak = any(
    h.get('command', '') == speak_cmd
    for entry in stop
    for h in entry.get('hooks', [])
)
if not already_has_speak:
    stop.append({
        "hooks": [{"type": "command", "command": speak_cmd, "timeout": 30}]
    })
    hooks['Stop'] = stop

# SessionEnd hook
session_end_cmd = f"bash {plugin_dir}/bin/session_end.sh"
session_end = hooks.get('SessionEnd', [])
already_has_end = any(
    h.get('command', '') == session_end_cmd
    for entry in session_end
    for h in entry.get('hooks', [])
)
if not already_has_end:
    session_end.append({
        "hooks": [{"type": "command", "command": session_end_cmd, "timeout": 10}]
    })
    hooks['SessionEnd'] = session_end

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print("  ✓ Hooks registered in " + settings_file)
MERGE_EOF
    fi
}

echo "  Registering for Cortex Code..."
register_cortex_code

echo "  Registering for Claude Code..."
register_claude_code

# --- Slash commands ---
echo ""
echo "[5/5] Installing slash commands..."

install_slash_commands() {
    local commands_dir="$1"
    local label="$2"

    mkdir -p "${commands_dir}"

    cat > "${commands_dir}/glados_mute.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_mute.sh
CMD_EOF

    cat > "${commands_dir}/glados_unmute.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_unmute.sh
CMD_EOF

    cat > "${commands_dir}/glados_mute_session.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_mute_session.sh
CMD_EOF

    cat > "${commands_dir}/glados_unmute_session.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_unmute_session.sh
CMD_EOF

    cat > "${commands_dir}/glados_restart_server.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_restart_server.sh
CMD_EOF

    cat > "${commands_dir}/glados_off.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_off.sh
CMD_EOF

    cat > "${commands_dir}/glados_off_all.md" << CMD_EOF
Run this command: bash ${PLUGIN_DIR}/bin/glados_off_all.sh
CMD_EOF

    echo "  ✓ ${label}: /glados_mute, /glados_unmute, /glados_mute_session, /glados_unmute_session, /glados_restart_server, /glados_off, /glados_off_all"
}

# Cortex Code commands
install_slash_commands "$HOME/.snowflake/cortex/commands" "Cortex Code"

# Claude Code commands (if ~/.claude exists)
if [[ -d "$HOME/.claude" ]]; then
    install_slash_commands "$HOME/.claude/commands" "Claude Code"
else
    echo "  - Claude Code not detected, skipping commands"
fi

# --- Done ---
echo ""
echo "======================================"
echo " Installation complete!"
echo "======================================"
echo ""
echo "Models:  ${MODELS_DIR}"
echo "Venv:    ${VENV_DIR}"
echo ""
echo "To test the TTS server manually:"
echo "  ${PLUGIN_DIR}/bin/serve.sh"
echo "  curl http://localhost:8124/synthesize/Hello%20test%20subject"
echo "  ${PLUGIN_DIR}/bin/stop.sh"
echo ""
echo "The TTS server starts on-demand when you activate the /glados skill."
echo "Only sessions that have opted in will receive audio output."
echo ""
echo "Slash commands available:"
echo "  /glados                 - Activate GLaDOS personality + TTS for this session"
echo "  /glados_mute            - Mute audio globally (all sessions)"
echo "  /glados_unmute          - Unmute audio globally"
echo "  /glados_mute_session    - Mute audio for this session only"
echo "  /glados_unmute_session  - Unmute audio for this session only"
echo "  /glados_restart_server  - Restart the TTS server"
