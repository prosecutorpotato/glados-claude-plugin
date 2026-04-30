#!/usr/bin/env bash
# glados_unmute.sh - Unmute GLaDOS TTS audio playback

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -f "${PLUGIN_ROOT}/tts/.muted"
echo "[GLaDOS TTS] Audio unmuted"
