""" from https://github.com/keithito/tacotron """

'''
Defines the set of symbols used in text input to the model.
'''

_pad = '_'
_punctuation = '!\'(),.:;? '
_special = '-'

# Phonemes
_vowels = 'iyɨʉɯuɪʏʊeøɘəɵɤoɛœɜɞʌɔæɐaɶɑɒᵻ'
_non_pulmonic_consonants = 'ʘɓǀɗǃʄǂɠǁʛ'
_pulmonic_consonants = 'pbtdʈɖcɟkɡqɢʔɴŋɲɳnɱmʙrʀⱱɾɽɸβfvθðszʃʒʂʐçʝxɣχʁħʕhɦɬɮʋɹɻjɰlɭʎʟ'
_suprasegmentals = 'ˈˌːˑ'
_other_symbols = 'ʍwɥʜʢʡɕʑɺɧ'
_diacrilics = 'ɚ˞ɫ'
_extra_phons = ['g', 'ɝ', '̃', '̍', '̥', '̩', '̯', '͡']

phonemes = list(
   _pad + _punctuation + _special + _vowels + _non_pulmonic_consonants
   + _pulmonic_consonants + _suprasegmentals + _other_symbols + _diacrilics) + _extra_phons

phonemes_set = set(phonemes)
silent_phonemes_indices = [i for i, p in enumerate(phonemes) if p in _pad + _punctuation]
