import io
import time
import unittest
import wave
from types import SimpleNamespace
from unittest.mock import patch

from transcribe import _pcm_to_wav, transcribe_audio, transcribe_encoded_audio


class FakeModel:
    def __init__(self, segments):
        self.segments = segments
        self.sources = []

    def transcribe(self, source, **kwargs):
        self.sources.append((source, kwargs))
        return iter(self.segments), SimpleNamespace(language="en")


class TranscriptionTests(unittest.TestCase):
    def test_pcm_conversion_has_expected_wave_format(self):
        pcm = b"\x00\x00\x01\x00" * 20
        converted = _pcm_to_wav(pcm, 16_000)

        with wave.open(converted, "rb") as audio:
            self.assertEqual(audio.getnchannels(), 1)
            self.assertEqual(audio.getsampwidth(), 2)
            self.assertEqual(audio.getframerate(), 16_000)
            self.assertEqual(audio.readframes(audio.getnframes()), pcm)

    def test_raw_transcription_joins_segments_and_calculates_confidence(self):
        model = FakeModel([
            SimpleNamespace(text=" hello ", avg_logprob=-0.2),
            SimpleNamespace(text="world", avg_logprob=-0.4),
        ])
        with patch("transcribe.get_whisper_model", return_value=model):
            result = transcribe_audio(b"\x00\x00" * 100)

        self.assertEqual(result.text, "hello world")
        self.assertAlmostEqual(result.confidence, 0.7)
        self.assertEqual(result.language, "en")
        self.assertIsInstance(model.sources[0][0], io.BytesIO)
        self.assertTrue(model.sources[0][1]["vad_filter"])

    def test_encoded_audio_is_not_wrapped_as_pcm(self):
        encoded = b"ID3-not-real-mp3"
        model = FakeModel([])
        with patch("transcribe.get_whisper_model", return_value=model):
            result = transcribe_encoded_audio(encoded)

        self.assertEqual(result.text, "")
        self.assertEqual(model.sources[0][0].read(), encoded)

    def test_missing_model_returns_stable_empty_result(self):
        with patch("transcribe.get_whisper_model", return_value=None):
            result = transcribe_audio(b"\x00\x00")

        self.assertEqual(result.text, "")
        self.assertEqual(result.confidence, 0.0)
        self.assertGreaterEqual(result.latency_ms, 0.0)


if __name__ == "__main__":
    unittest.main()
