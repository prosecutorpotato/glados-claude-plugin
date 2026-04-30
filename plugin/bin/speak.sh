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
    # Split text into sentence-bounded chunks (max ~900 chars each, within server's 1000 limit)
    # and synthesize/play them sequentially so the full response is spoken.
    CHUNKS=$(python3 -c "
import sys, re, json

text = sys.argv[1]
limit = 900
chunks = []

while text:
    text = text.strip()
    if not text:
        break
    if len(text) <= limit:
        chunks.append(text)
        break
    # Find the last sentence boundary within the limit
    window = text[:limit]
    matches = list(re.finditer(r'[.!?](?:\s|$)', window))
    if matches:
        end = matches[-1].end()
        chunks.append(window[:end].strip())
        text = text[end:]
    else:
        # No sentence boundary; cut at last space
        last_space = window.rfind(' ')
        if last_space > 0:
            chunks.append(window[:last_space].strip())
            text = text[last_space:]
        else:
            chunks.append(window)
            text = text[limit:]

# Output as JSON array
print(json.dumps(chunks))
" "${RESPONSE_TEXT}")

    # Play each chunk sequentially
    echo "${CHUNKS}" | python3 -c "
import sys, json
chunks = json.load(sys.stdin)
for chunk in chunks:
    print(chunk)
" | while IFS= read -r CHUNK; do
        if [[ -z "${CHUNK}" ]]; then
            continue
        fi

        # URL-encode the chunk
        ENCODED_TEXT=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${CHUNK}")

        # Use a unique temp file
        AUDIO_TMP=$(mktemp /tmp/glados-tts-XXXXXXXXXXXX) && mv "${AUDIO_TMP}" "${AUDIO_TMP}.wav" && AUDIO_TMP="${AUDIO_TMP}.wav"

        HTTP_CODE=$(curl -s -o "${AUDIO_TMP}" -w "%{http_code}" \
            "http://localhost:8124/synthesize/${ENCODED_TEXT}" 2>/dev/null || echo "000")

        if [[ "${HTTP_CODE}" == "200" && -s "${AUDIO_TMP}" ]]; then
            if command -v afplay &>/dev/null; then
                afplay "${AUDIO_TMP}"
            elif command -v aplay &>/dev/null; then
                aplay "${AUDIO_TMP}"
            fi
        fi
        rm -f "${AUDIO_TMP}"
    done
) &>/dev/null &
disown

exit 0
