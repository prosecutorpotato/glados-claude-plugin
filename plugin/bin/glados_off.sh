#!/usr/bin/env bash
# glados_off.sh - Deactivate GLaDOS TTS for the current session
# Unregisters this session from TTS. Stops the server if no sessions remain.

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${PLUGIN_ROOT}/bin/glados_deactivate.sh"
