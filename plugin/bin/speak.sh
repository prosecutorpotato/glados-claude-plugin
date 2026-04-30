#!/usr/bin/env bash
# speak.sh - Synthesize the latest response via GLaDOS TTS (Stop hook)
# Reads the assistant's last response from the transcript, sends to TTS server,
# and plays the resulting audio.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${PLUGIN_ROOT}/lib/tts-helpers.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract transcript path from hook input
TRANSCRIPT_PATH=$(echo "${INPUT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('transcript_path', ''))
" 2>/dev/null || echo "")

if [[ -z "${TRANSCRIPT_PATH}" || ! -f "${TRANSCRIPT_PATH}" ]]; then
    exit 0  # No transcript available, skip silently
fi

# Check if server is running
if ! is_server_running; then
    exit 0  # Server not running, skip silently
fi

# Extract the last assistant response text
RESPONSE_TEXT=$("${PLUGIN_ROOT}/bin/extract-response.py" "${TRANSCRIPT_PATH}")

if [[ -z "${RESPONSE_TEXT}" ]]; then
    exit 0
fi

# Fork synthesis + playback into background so the hook exits immediately
# and the text response is shown to the user without delay.
(
    # Truncate long responses for TTS (keep first ~500 chars, UTF-8 safe)
    RESPONSE_TEXT=$(python3 -c "import sys; print(sys.argv[1][:500])" "${RESPONSE_TEXT}")

    # URL-encode the text and call TTS server
    ENCODED_TEXT=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${RESPONSE_TEXT}")

    # Use a unique temp file to avoid race conditions
    AUDIO_TMP=$(mktemp /tmp/glados-tts-XXXXXXXXXXXX) && mv "${AUDIO_TMP}" "${AUDIO_TMP}.wav" && AUDIO_TMP="${AUDIO_TMP}.wav"

    HTTP_CODE=$(curl -s -o "${AUDIO_TMP}" -w "%{http_code}" \
        "http://localhost:8124/synthesize/${ENCODED_TEXT}" 2>/dev/null || echo "000")

    if [[ "${HTTP_CODE}" == "200" && -s "${AUDIO_TMP}" ]]; then
        if command -v afplay &>/dev/null; then
            afplay "${AUDIO_TMP}"
        elif command -v aplay &>/dev/null; then
            aplay "${AUDIO_TMP}"
        fi
        rm -f "${AUDIO_TMP}"
    else
        rm -f "${AUDIO_TMP}"
    fi
) &>/dev/null &
disown

exit 0
