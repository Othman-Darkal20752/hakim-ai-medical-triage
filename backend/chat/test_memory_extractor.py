from collections.abc import Sequence

from django.test import SimpleTestCase

from .services.ai.exceptions import AIProviderTimeoutError
from .services.ai.memory_schemas import (
    MemoryCandidate,
    MemoryCandidateExtraction,
)
from .services.ai.provider import (
    AIMessage,
    AIProvider,
    AIProviderResult,
)
from .services.memory_extractor import extract_memory_candidates


class _MemoryTestProvider(AIProvider):
    def __init__(
        self,
        *,
        raw_json: str = '{"candidates":[]}',
        error: Exception | None = None,
    ) -> None:
        self.raw_json = raw_json
        self.error = error
        self.call_count = 0
        self.received_messages: Sequence[AIMessage] | None = None

    def generate_structured(
        self,
        *,
        messages: Sequence[AIMessage],
    ) -> AIProviderResult:
        self.call_count += 1
        self.received_messages = messages

        if self.error is not None:
            raise self.error

        return AIProviderResult(
            provider="test-provider",
            model="test-model",
            raw_json=self.raw_json,
        )


class MemoryExtractorTests(SimpleTestCase):
    def test_extracts_valid_candidate(self):
        provider = _MemoryTestProvider(
            raw_json=(
                '{"candidates":[{'
                '"field":"allergies",'
                '"operation":"add",'
                '"value":"Penicillin"'
                '}]}'
            )
        )

        result = extract_memory_candidates(
            ai_provider=provider,
            current_patient_message=(
                "I am allergic to Penicillin."
            ),
        )

        self.assertEqual(
            result,
            MemoryCandidateExtraction(
                candidates=(
                    MemoryCandidate(
                        field="allergies",
                        operation="add",
                        value="Penicillin",
                    ),
                ),
            ),
        )

    def test_valid_empty_extraction_is_not_failure(self):
        provider = _MemoryTestProvider(
            raw_json='{"candidates":[]}'
        )

        result = extract_memory_candidates(
            ai_provider=provider,
            current_patient_message="I have a headache.",
        )

        self.assertEqual(
            result,
            MemoryCandidateExtraction(candidates=()),
        )

    def test_builds_minimal_context_without_previous_assistant(self):
        provider = _MemoryTestProvider()

        extract_memory_candidates(
            ai_provider=provider,
            current_patient_message="  I take Metformin.  ",
        )

        self.assertIsNotNone(provider.received_messages)

        messages = tuple(provider.received_messages or ())

        self.assertEqual(
            tuple(message.role for message in messages),
            (
                "system",
                "user",
            ),
        )

        self.assertEqual(
            messages[-1].content,
            "I take Metformin.",
        )

        self.assertIn(
            "hakim-memory-candidate-v1",
            messages[0].content,
        )

    def test_includes_only_previous_assistant_message_as_context(self):
        provider = _MemoryTestProvider()

        extract_memory_candidates(
            ai_provider=provider,
            previous_assistant_message=(
                "Do you have any known medication allergies?"
            ),
            current_patient_message="Penicillin",
        )

        messages = tuple(provider.received_messages or ())

        self.assertEqual(
            tuple(message.role for message in messages),
            (
                "system",
                "assistant",
                "user",
            ),
        )

        self.assertEqual(
            messages[1].content,
            "Do you have any known medication allergies?",
        )
        self.assertEqual(
            messages[2].content,
            "Penicillin",
        )

    def test_ai_service_error_is_fail_soft(self):
        provider = _MemoryTestProvider(
            error=AIProviderTimeoutError()
        )

        result = extract_memory_candidates(
            ai_provider=provider,
            current_patient_message="I take Metformin.",
        )

        self.assertIsNone(result)
        self.assertEqual(provider.call_count, 1)

    def test_invalid_ai_json_is_fail_soft(self):
        provider = _MemoryTestProvider(
            raw_json="{invalid-json"
        )

        result = extract_memory_candidates(
            ai_provider=provider,
            current_patient_message="I take Metformin.",
        )

        self.assertIsNone(result)

    def test_unexpected_provider_error_is_not_hidden(self):
        provider = _MemoryTestProvider(
            error=RuntimeError("programming failure")
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "programming failure",
        ):
            extract_memory_candidates(
                ai_provider=provider,
                current_patient_message="I take Metformin.",
            )

    def test_non_string_patient_message_is_rejected(self):
        provider = _MemoryTestProvider()

        with self.assertRaisesRegex(
            TypeError,
            "current_patient_message must be a string",
        ):
            extract_memory_candidates(
                ai_provider=provider,
                current_patient_message=123,
            )

        self.assertEqual(provider.call_count, 0)

    def test_blank_patient_message_is_rejected(self):
        provider = _MemoryTestProvider()

        with self.assertRaisesRegex(
            ValueError,
            "current_patient_message must not be blank",
        ):
            extract_memory_candidates(
                ai_provider=provider,
                current_patient_message="   ",
            )

        self.assertEqual(provider.call_count, 0)

    def test_blank_previous_assistant_message_is_rejected(self):
        provider = _MemoryTestProvider()

        with self.assertRaisesRegex(
            ValueError,
            "previous_assistant_message must not be blank",
        ):
            extract_memory_candidates(
                ai_provider=provider,
                previous_assistant_message="   ",
                current_patient_message="Penicillin",
            )

        self.assertEqual(provider.call_count, 0)
