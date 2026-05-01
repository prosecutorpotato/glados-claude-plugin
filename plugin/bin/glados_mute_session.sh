#!/usr/bin/env bash
# glados_mute_session.sh - Mute GLaDOS TTS for the current session only

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${PLUGIN_ROOT}/bin/glados_mute.sh" --session
