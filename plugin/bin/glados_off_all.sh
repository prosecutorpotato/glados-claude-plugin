#!/usr/bin/env bash
# glados_off_all.sh - Deactivate GLaDOS TTS for ALL sessions and stop the server

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${PLUGIN_ROOT}/lib/tts-helpers.sh"

SESSIONS_DIR="${PLUGIN_ROOT}/tts/sessions"

# Remove all session registrations and per-session mute files
if [[ -d "${SESSIONS_DIR}" ]]; then
    rm -f "${SESSIONS_DIR}"/*
    rm -f "${SESSIONS_DIR}"/.muted-*
fi

# Stop the server
if is_server_running; then
    "${PLUGIN_ROOT}/bin/stop.sh"
fi

echo "[GLaDOS TTS] All sessions deactivated — server stopped"
