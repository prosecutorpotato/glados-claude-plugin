"""
Text preparation for GLaDOS TTS using IPA phoneme encoding.
Matches the original R2D2FISH/glados-tts pipeline.
"""

import torch

from utils.text.cleaners import Cleaner
from utils.text.tokenizer import Tokenizer

# Cache these at module level to avoid reloading the 63MB phonemizer model per request
_cleaner = Cleaner('english_cleaners', True, 'en-us')
_tokenizer = Tokenizer()


def prepare_text(text: str) -> torch.Tensor:
    """Convert text to phoneme token tensor for model input."""
    # Ensure text ends with sentence-ending punctuation
    if not ((text[-1] == '.') or (text[-1] == '?') or (text[-1] == '!')):
        text = text + '.'
    return torch.as_tensor(_tokenizer(_cleaner(text)), dtype=torch.long, device='cpu').unsqueeze(0)
