"""Compute waveform amplitude samples from an audio file.

Used by sound-check.py to pre-compute waveform data for the sound picker UI,
avoiding runtime AVAudioFile processing in the app.
"""

from pydub import AudioSegment


def compute_waveform(audio_path, bar_count=25):
    """Return a list of normalized amplitudes (0.0–1.0) for waveform display.

    Decodes the audio file into raw samples, divides into bar_count chunks,
    and computes mean absolute amplitude per chunk.
    """
    audio = AudioSegment.from_file(str(audio_path))
    samples = audio.get_array_of_samples()

    if not samples:
        return [0.0] * bar_count

    # For stereo, interleave means we take every Nth sample for one channel
    # — simpler to just use all samples since we only care about amplitude.
    total = len(samples)
    chunk_size = total // bar_count

    if chunk_size == 0:
        return [0.0] * bar_count

    amplitudes = []
    for i in range(bar_count):
        start = i * chunk_size
        end = start + chunk_size if i < bar_count - 1 else total
        chunk = samples[start:end]
        mean_abs = sum(abs(s) for s in chunk) / len(chunk)
        amplitudes.append(mean_abs)

    max_amp = max(amplitudes) if amplitudes else 1.0
    if max_amp > 0:
        amplitudes = [round(a / max_amp, 2) for a in amplitudes]
    else:
        amplitudes = [0.0] * bar_count

    return amplitudes
