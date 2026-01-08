"""
RepoWhisper Audio Transcription
Faster-Whisper integration for real-time speech-to-text.
Optimized for sub-200ms latency on Apple Silicon.
"""

import time
import io
import wave
import struct
from typing import Optional
from dataclasses import dataclass
from functools import lru_cache

try:
    from faster_whisper import WhisperModel
    WHISPER_AVAILABLE = True
except ImportError:
    WHISPER_AVAILABLE = False
    WhisperModel = None  # type: ignore

from config import get_settings


@dataclass
class TranscriptionResult:
    """Result of audio transcription."""
    text: str
    confidence: float
    latency_ms: float
    language: str


# ============ Model Management ============

@lru_cache(maxsize=1)
def get_whisper_model() -> Optional[WhisperModel]:
    """
    Load and cache the Faster-Whisper model.
    
    Uses 'tiny.en' for fastest inference (~100-200ms).
    For better accuracy, use 'base.en' or 'small.en'.
    
    Returns None if faster-whisper is not installed.
    """
    if not WHISPER_AVAILABLE:
        print("⚠️  faster-whisper not installed. Install with: pip install faster-whisper")
        return None
    
    settings = get_settings()
    
    # Determine compute type based on platform
    # Apple Silicon: use int8 for speed
    # CUDA: use float16
    compute_type = "int8"
    device = "cpu"  # Use 'cuda' if GPU available
    
    print(f"Loading Whisper model: {settings.whisper_model}")
    model = WhisperModel(
        settings.whisper_model,
        device=device,
        compute_type=compute_type,
        cpu_threads=4,
        num_workers=1
    )
    
    # Warm up the model with silence
    warmup_audio = _generate_silence(0.1)
    list(model.transcribe(warmup_audio, language="en"))
    print("Whisper model loaded and warmed up")
    
    return model


def _generate_silence(duration_seconds: float) -> io.BytesIO:
    """Generate silent audio for model warmup."""
    sample_rate = 16000
    num_samples = int(sample_rate * duration_seconds)
    
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(struct.pack(f'{num_samples}h', *([0] * num_samples)))
    
    buffer.seek(0)
    return buffer


# ============ Transcription Functions ============

def transcribe_audio(
    audio_data: bytes,
    sample_rate: int = 16000,
    language: str = "en"
) -> TranscriptionResult:
    """
    Transcribe raw PCM audio data to text.
    
    Args:
        audio_data: Raw PCM audio bytes (16-bit signed, mono)
        sample_rate: Audio sample rate (default 16kHz)
        language: Language code (default 'en')
        
    Returns:
        TranscriptionResult with text and metadata
    """
    start_time = time.perf_counter()
    
    model = get_whisper_model()
    
    if model is None:
        # Fallback: return empty transcription if Whisper not available
        return TranscriptionResult(
            text="",
            confidence=0.0,
            latency_ms=(time.perf_counter() - start_time) * 1000,
            language=language
        )
    
    # Convert raw PCM to WAV format for Whisper
    wav_buffer = _pcm_to_wav(audio_data, sample_rate)
    
    # Transcribe
    segments, info = model.transcribe(
        wav_buffer,
        language=language,
        beam_size=1,           # Fastest
        best_of=1,             # No sampling
        temperature=0.0,       # Greedy decoding
        vad_filter=True,       # Skip silence
        vad_parameters={
            "min_silence_duration_ms": 200,
            "speech_pad_ms": 100
        }
    )
    
    # Collect transcription
    text_parts = []
    total_prob = 0.0
    segment_count = 0
    
    for segment in segments:
        text_parts.append(segment.text.strip())
        total_prob += segment.avg_logprob
        segment_count += 1
    
    # Calculate average confidence
    avg_confidence = 0.0
    if segment_count > 0:
        # Convert log probability to rough confidence score
        avg_logprob = total_prob / segment_count
        avg_confidence = min(1.0, max(0.0, 1.0 + avg_logprob))
    
    text = " ".join(text_parts).strip()
    latency_ms = (time.perf_counter() - start_time) * 1000
    
    return TranscriptionResult(
        text=text,
        confidence=avg_confidence,
        latency_ms=latency_ms,
        language=info.language if info else language
    )


def _pcm_to_wav(pcm_data: bytes, sample_rate: int) -> io.BytesIO:
    """Convert raw PCM bytes to WAV format."""
    buffer = io.BytesIO()
    
    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(1)          # Mono
        wav.setsampwidth(2)          # 16-bit
        wav.setframerate(sample_rate)
        wav.writeframes(pcm_data)
    
    buffer.seek(0)
    return buffer


def transcribe_file(file_path: str, language: str = "en") -> TranscriptionResult:
    """
    Transcribe an audio file.
    
    Args:
        file_path: Path to audio file (WAV, MP3, etc.)
        language: Language code
        
    Returns:
        TranscriptionResult
    """
    start_time = time.perf_counter()
    
    model = get_whisper_model()
    
    if model is None:
        return TranscriptionResult(
            text="",
            confidence=0.0,
            latency_ms=(time.perf_counter() - start_time) * 1000,
            language=language
        )
    
    segments, info = model.transcribe(
        file_path,
        language=language,
        beam_size=1,
        best_of=1,
        temperature=0.0,
        vad_filter=True
    )
    
    text_parts = []
    total_prob = 0.0
    segment_count = 0
    
    for segment in segments:
        text_parts.append(segment.text.strip())
        total_prob += segment.avg_logprob
        segment_count += 1
    
    avg_confidence = 0.0
    if segment_count > 0:
        avg_logprob = total_prob / segment_count
        avg_confidence = min(1.0, max(0.0, 1.0 + avg_logprob))
    
    text = " ".join(text_parts).strip()
    latency_ms = (time.perf_counter() - start_time) * 1000
    
    return TranscriptionResult(
        text=text,
        confidence=avg_confidence,
        latency_ms=latency_ms,
        language=info.language if info else language
    )


# ============ Streaming Support ============

class StreamingTranscriber:
    """
    Handles streaming audio transcription.
    Accumulates audio chunks and transcribes on voice activity.
    """
    
    def __init__(
        self,
        sample_rate: int = 16000,
        chunk_duration_ms: int = 1000,
        language: str = "en"
    ):
        self.sample_rate = sample_rate
        self.chunk_duration_ms = chunk_duration_ms
        self.language = language
        self.buffer = bytearray()
        self.min_chunk_bytes = int(sample_rate * 2 * (chunk_duration_ms / 1000))
    
    def add_audio(self, audio_data: bytes) -> Optional[TranscriptionResult]:
        """
        Add audio data to the buffer.
        
        Returns TranscriptionResult if enough audio accumulated.
        """
        self.buffer.extend(audio_data)
        
        if len(self.buffer) >= self.min_chunk_bytes:
            # Transcribe accumulated audio
            result = transcribe_audio(
                bytes(self.buffer),
                self.sample_rate,
                self.language
            )
            self.buffer.clear()
            return result
        
        return None
    
    def flush(self) -> Optional[TranscriptionResult]:
        """Transcribe any remaining audio in the buffer."""
        if len(self.buffer) > 0:
            result = transcribe_audio(
                bytes(self.buffer),
                self.sample_rate,
                self.language
            )
            self.buffer.clear()
            return result
        return None
    
    def reset(self):
        """Clear the audio buffer."""
        self.buffer.clear()

