"""
GLaDOS TTS Runner - Forward Tacotron + HiFiGAN vocoder
Adapted from R2D2FISH/glados-tts for plugin-local operation.

Model files required in models/:
  - glados-new.pt (Forward Tacotron)
  - vocoder-gpu.pt (HiFiGAN)
  - emb/glados_p2.pt (speaker embedding)
"""

import os
import sys
import torch
import numpy as np
from scipy.io.wavfile import write as write_wav
from pydub import AudioSegment
from io import BytesIO

# Ensure utils is importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils.tools import prepare_text


class TTSRunner:
    """GLaDOS neural TTS: Forward Tacotron encoder + HiFiGAN vocoder."""

    def __init__(self, models_dir=None, use_p1=False, log=False):
        self.log = log
        if models_dir is None:
            models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

        self.device = torch.device("cpu")
        if torch.cuda.is_available():
            self.device = torch.device("cuda")

        if self.log:
            print(f"[GLaDOS TTS] Using device: {self.device}")
            print(f"[GLaDOS TTS] Loading models from: {models_dir}")

        # Load speaker embedding
        emb_path = os.path.join(models_dir, "emb", "glados_p2.pt")
        self.emb = torch.load(emb_path, map_location=self.device, weights_only=True)

        # Load Forward Tacotron model
        glados_path = os.path.join(models_dir, "glados-new.pt")
        self.glados = torch.jit.load(glados_path, map_location=self.device)

        # Load HiFiGAN vocoder
        vocoder_path = os.path.join(models_dir, "vocoder-gpu.pt")
        self.vocoder = torch.jit.load(vocoder_path, map_location=self.device)

        if self.log:
            print("[GLaDOS TTS] Models loaded successfully")

    def run_tts(self, text, alpha=1.0):
        """Synthesize text to audio. Returns pydub AudioSegment."""
        # Prepare text input
        x = prepare_text(text).to(self.device)

        with torch.no_grad():
            # Generate mel spectrogram with Forward Tacotron
            tts_output = self.glados.generate_jit(x, self.emb, alpha)

            # Extract post-net mel and vocode with HiFiGAN
            mel = tts_output['mel_post'].to(self.device)
            audio = self.vocoder(mel)

        # Convert to numpy and normalize
        audio_np = audio.squeeze().cpu().numpy()
        audio_np = audio_np * 32767.0
        audio_np = audio_np.astype(np.int16)

        # Convert to AudioSegment via WAV buffer
        buffer = BytesIO()
        write_wav(buffer, 22050, audio_np)
        buffer.seek(0)

        return AudioSegment.from_wav(buffer)
