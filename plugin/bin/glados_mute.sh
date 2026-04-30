#!/usr/bin/env bash
# glados_mute.sh - Mute GLaDOS TTS audio playback

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
touch "${PLUGIN_ROOT}/tts/.muted"
echo "[GLaDOS TTS] Audio muted"
