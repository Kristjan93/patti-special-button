"""Split audio files into segments at silence boundaries.

Used by sound-check.py to break multi-event sound files (e.g. multiple farts
in one recording) into individual segments for shuffle playback.
"""

from pathlib import Path

from pydub import AudioSegment
from pydub.silence import detect_nonsilent


def split_segments(
    audio_path,
    output_dir,
    base_name,
    silence_thresh=-40,
    min_silence_len=200,
    padding_ms=50,
    min_segment_ms=100,
):
    """Split an audio file at silence boundaries and export segments as WAV.

    Returns a list of Path objects for the exported segment files.
    Segments shorter than min_segment_ms are discarded.
    """
    audio = AudioSegment.from_file(str(audio_path))
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    ranges = detect_nonsilent(
        audio,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh,
    )

    if not ranges:
        return []

    exported = []
    for i, (start_ms, end_ms) in enumerate(ranges):
        # Add padding around each segment boundary
        seg_start = max(0, start_ms - padding_ms)
        seg_end = min(len(audio), end_ms + padding_ms)

        if (seg_end - seg_start) < min_segment_ms:
            continue

        segment = audio[seg_start:seg_end]
        filename = f"shuffle_{base_name}_{i:02d}.wav"
        out_path = output_dir / filename
        segment.export(str(out_path), format="wav")
        exported.append(out_path)

    return exported
