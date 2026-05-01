#!/usr/bin/env bash
# glados_mute.sh - Mute GLaDOS TTS audio playback
# Usage: glados_mute.sh [--session]
#   --session: Mute only the current session (uses CORTEX_SESSION_ID)
#   No flag: Mute all sessions globally

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${1:-}" == "--session" ]]; then
    SESSION_ID="${CORTEX_SESSION_ID:-${CLAUDE_SESSION_ID:-unknown}}"
    mkdir -p "${PLUGIN_ROOT}/tts/sessions"
    touch "${PLUGIN_ROOT}/tts/sessions/.muted-${SESSION_ID}"
    echo "[GLaDOS TTS] Audio muted for this session (${SESSION_ID:0:8}...)"
else
    touch "${PLUGIN_ROOT}/tts/.muted"
    echo "[GLaDOS TTS] Audio muted globally (all sessions)"
fi
