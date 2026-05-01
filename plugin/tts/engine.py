"""
GLaDOS TTS Flask Server
Exposes /synthesize/<text> endpoint on port 8124.
Adapted from R2D2FISH/glados-tts engine.py for plugin-local paths.
"""

import os
import sys
import hashlib
import glob as glob_module
from flask import Flask, send_file, abort

# Add plugin tts dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from glados import TTSRunner

app = Flask(__name__)

# Resolve models dir relative to this file
PLUGIN_TTS_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(PLUGIN_TTS_DIR, "models")

# Audio output goes to state directory (set by serve.sh via GLADOS_AUDIO_DIR env var)
AUDIO_DIR = os.environ.get("GLADOS_AUDIO_DIR", os.path.join(PLUGIN_TTS_DIR, "audio"))

os.makedirs(AUDIO_DIR, exist_ok=True)

# Clean stale audio cache on startup
for f in glob_module.glob(os.path.join(AUDIO_DIR, "GLaDOS-tts-*.wav")):
    try:
        os.remove(f)
    except OSError:
        pass

# Max input length (characters) to prevent abuse
MAX_INPUT_LENGTH = 1000

# Initialize TTS runner
print("[GLaDOS TTS] Initializing engine...")
glados = TTSRunner(models_dir=MODELS_DIR, log=True)
print("[GLaDOS TTS] Engine ready on port 8124")


def glados_tts(text, key=None, alpha=1.0):
    """Synthesize text and save to audio file. Returns output path."""
    if key is None:
        key = hashlib.sha256(text.encode()).hexdigest()[:16]

    output_file = os.path.join(AUDIO_DIR, f"GLaDOS-tts-{key}.wav")
    glados.run_tts(text, alpha).export(output_file, format="wav")
    return output_file


@app.route("/synthesize/<path:text>")
def synthesize(text):
    """Synthesize text to speech and return WAV audio."""
    if len(text) > MAX_INPUT_LENGTH:
        abort(413, description=f"Input exceeds {MAX_INPUT_LENGTH} character limit")

    key = hashlib.sha256(text.encode()).hexdigest()[:16]
    output_file = glados_tts(text, key=key)
    return send_file(output_file, mimetype="audio/wav")


@app.route("/health")
def health():
    """Health check endpoint."""
    return {"status": "ok", "engine": "glados-tts"}


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8124)
