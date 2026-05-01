#!/usr/bin/env bash
# glados_unmute_session.sh - Unmute GLaDOS TTS for the current session only

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${PLUGIN_ROOT}/bin/glados_unmute.sh" --session
