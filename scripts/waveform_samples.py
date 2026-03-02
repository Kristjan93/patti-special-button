"""Compute waveform amplitude samples from an audio file.

Used by sound-check.py to pre-compute waveform data for the sound picker UI,
avoiding runtime AVAudioFile processing in the app.
"""

import numpy as np
from scipy.io import wavfile


def _load_as_float_mono(audio_path):
    """Load audio as mono float32 samples normalized to [-1, 1].

    Uses scipy for WAV files (zero extra deps), falls back to pydub for MP3/others.
    """
    path = str(audio_path)
    if path.lower().endswith(".wav"):
        rate, data = wavfile.read(path)
        arr = data.astype(np.float32)
        # Normalize integer formats to [-1, 1]
        if data.dtype == np.int16:
            arr /= 32768.0
        elif data.dtype == np.int32:
            arr /= 2147483648.0
        elif data.dtype == np.uint8:
            arr = (arr - 128.0) / 128.0
        # float32/float64 WAVs are already in [-1, 1]
    else:
        from pydub import AudioSegment
        audio = AudioSegment.from_file(path)
        raw = np.array(audio.get_array_of_samples(), dtype=np.float32)
        bit_depth = audio.sample_width * 8
        raw /= 2.0 ** (bit_depth - 1)
        if audio.channels > 1:
            arr = raw.reshape(-1, audio.channels)
        else:
            arr = raw

    # Mix stereo (or multi-channel) down to mono by averaging channels
    if arr.ndim > 1:
        arr = arr.mean(axis=1)

    return arr


def compute_waveform(audio_path, bar_count=25):
    """Return a list of normalized amplitudes (0.0–1.0) for waveform display.

    Loads audio, mixes to mono, splits into bar_count chunks,
    and computes RMS amplitude per chunk.
    """
    samples = _load_as_float_mono(audio_path)

    if len(samples) == 0:
        return [0.0] * bar_count

    # Split into bar_count chunks and compute RMS per chunk
    chunks = np.array_split(samples, bar_count)
    amplitudes = np.array([np.sqrt(np.mean(chunk ** 2)) for chunk in chunks])

    max_amp = amplitudes.max()
    if max_amp > 0:
        amplitudes /= max_amp

    return [round(float(a), 2) for a in amplitudes]
