#!/usr/bin/env bash
# glados_restart_server.sh - Restart the GLaDOS TTS server

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"${PLUGIN_ROOT}/bin/stop.sh"
"${PLUGIN_ROOT}/bin/serve.sh"
