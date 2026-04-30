#!/usr/bin/env bash
# tts-helpers.sh - Shared utility functions for GLaDOS TTS scripts

TTS_PORT=8124
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PID_FILE="${PLUGIN_ROOT}/tts/server.pid"

is_server_running() {
    # Check by PID file first
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
        # Stale PID file
        rm -f "${PID_FILE}"
    fi

    # Check by port
    if curl -sf "http://localhost:${TTS_PORT}/health" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

wait_for_server() {
    local timeout="${1:-10}"
    local elapsed=0

    while (( elapsed < timeout )); do
        if curl -sf "http://localhost:${TTS_PORT}/health" >/dev/null 2>&1; then
            echo "[GLaDOS TTS] Server ready"
            return 0
        fi
        sleep 1
        (( elapsed++ ))
    done

    echo "[GLaDOS TTS] Server failed to start within ${timeout}s" >&2
    return 1
}
