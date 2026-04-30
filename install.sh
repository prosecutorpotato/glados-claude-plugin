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

# --- Audio directory ---
echo ""
echo "[3/4] Creating audio cache directory..."
mkdir -p "${TTS_DIR}/audio"
echo "  ✓ Done"

# --- Global registration ---
echo ""
echo "[4/4] Registering plugin globally..."

register_cortex_code() {
    local config_dir="$HOME/.snowflake/cortex"
    local settings_file="${config_dir}/settings.json"
    local skills_dir="${config_dir}/skills/glados"

    # Install skill files
    mkdir -p "${skills_dir}"
    cp -f "${PLUGIN_DIR}/skills/glados/"*.md "${skills_dir}/"
    echo "  ✓ GLaDOS skill installed to ${skills_dir}"

    # Register hooks in settings.json
    if [[ ! -f "${settings_file}" ]]; then
        # Create minimal settings with hooks
        mkdir -p "${config_dir}"
        cat > "${settings_file}" << SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/serve.sh",
            "timeout": 30
          }
        ]
      }
    ],
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
    ]
  }
}
SETTINGS_EOF
        echo "  ✓ Created ${settings_file} with hooks"
    else
        # Merge hooks into existing settings using Python
        python3 << MERGE_EOF
import json, sys

settings_file = "${settings_file}"
plugin_dir = "${PLUGIN_DIR}"

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# SessionStart hook
serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
session_start = hooks.get('SessionStart', [])
# Check if already registered
already_has_serve = any(
    h.get('command', '') == serve_cmd
    for entry in session_start
    for h in entry.get('hooks', [])
)
if not already_has_serve:
    session_start.append({
        "hooks": [{"type": "command", "command": serve_cmd, "timeout": 30}]
    })
    hooks['SessionStart'] = session_start

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

    # Claude Code uses a different settings structure
    if [[ ! -d "${config_dir}" ]]; then
        echo "  - Claude Code not detected (no ~/.claude), skipping"
        return 0
    fi

    if [[ ! -f "${settings_file}" ]]; then
        cat > "${settings_file}" << SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${PLUGIN_DIR}/bin/serve.sh",
            "timeout": 30
          }
        ]
      }
    ],
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

serve_cmd = f"bash {plugin_dir}/bin/serve.sh"
session_start = hooks.get('SessionStart', [])
already_has_serve = any(
    h.get('command', '') == serve_cmd
    for entry in session_start
    for h in entry.get('hooks', [])
)
if not already_has_serve:
    session_start.append({
        "hooks": [{"type": "command", "command": serve_cmd, "timeout": 30}]
    })
    hooks['SessionStart'] = session_start

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
echo "The plugin will auto-start the TTS server when a session begins."
echo "Use /glados in-session to activate the GLaDOS personality."
