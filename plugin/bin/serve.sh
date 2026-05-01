#!/usr/bin/env bash
# serve.sh - Start the GLaDOS TTS server (SessionStart hook)
# Ensures the TTS Flask server is running on port 8124.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${PLUGIN_ROOT}/lib/tts-helpers.sh"

# Check if server is already running
if is_server_running; then
    exit 0
fi

# Check if models are installed
if [[ ! -f "${PLUGIN_ROOT}/tts/models/glados-new.pt" ]]; then
    echo "[GLaDOS TTS] Models not found. Run install.sh first." >&2
    exit 0  # Don't block session start
fi

# Check if venv exists
VENV_DIR="${PLUGIN_ROOT}/tts/.venv"
if [[ ! -d "${VENV_DIR}" ]]; then
    echo "[GLaDOS TTS] Virtual environment not found. Run install.sh first." >&2
    exit 0
fi

# Ensure audio cache directory exists
mkdir -p "${GLADOS_STATE_DIR}/audio"

# Start TTS server in background
echo "[GLaDOS TTS] Starting server..."
GLADOS_AUDIO_DIR="${GLADOS_STATE_DIR}/audio" \
"${VENV_DIR}/bin/python" "${PLUGIN_ROOT}/tts/engine.py" \
    > "${GLADOS_STATE_DIR}/server.log" 2>&1 &

SERVER_PID=$!
echo "${SERVER_PID}" > "${GLADOS_STATE_DIR}/server.pid"

# Wait for server to become ready (max 25s - model loading includes 63MB phonemizer)
wait_for_server 25

exit 0
