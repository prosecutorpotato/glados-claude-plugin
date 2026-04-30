#!/usr/bin/env bash
# stop.sh - Stop the GLaDOS TTS server

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PID_FILE="${PLUGIN_ROOT}/tts/server.pid"

if [[ -f "${PID_FILE}" ]]; then
    PID=$(cat "${PID_FILE}")
    if kill -0 "${PID}" 2>/dev/null; then
        # Verify the process is actually our Python TTS server before killing
        PROC_CMD=$(ps -p "${PID}" -o command= 2>/dev/null || true)
        if [[ "${PROC_CMD}" == *"engine.py"* ]]; then
            kill "${PID}" 2>/dev/null || true
            echo "[GLaDOS TTS] Server stopped (PID ${PID})"
        else
            echo "[GLaDOS TTS] PID ${PID} is not the TTS server, skipping" >&2
        fi
    fi
    rm -f "${PID_FILE}"
fi

exit 0
