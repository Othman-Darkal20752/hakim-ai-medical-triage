import json

from django.test import SimpleTestCase

from .services.ai.exceptions import AIInvalidResponseError
from .services.ai.memory_schemas import (
    MemoryCandidate,
    MemoryCandidateExtraction,
    parse_memory_candidate_extraction,
)


class MemoryCandidateSchemaTests(SimpleTestCase):
    def test_accepts_empty_candidate_list(self):
        result = parse_memory_candidate_extraction(
            '{"candidates":[]}'
        )

        self.assertEqual(
            result,
            MemoryCandidateExtraction(candidates=()),
        )

    def test_parses_list_add_candidate(self):
        result = parse_memory_candidate_extraction(
            json.dumps(
                {
                    "candidates": [
                        {
                            "field": "allergies",
                            "operation": "add",
                            "value": "  Penicillin  ",
                        }
                    ]
                }
            )
        )

        self.assertEqual(
            result.candidates,
            (
                MemoryCandidate(
                    field="allergies",
                    operation="add",
                    value="Penicillin",
                ),
            ),
        )

    def test_parses_list_remove_candidate(self):
        result = parse_memory_candidate_extraction(
            json.dumps(
                {
                    "candidates": [
                        {
                            "field": "current_medications",
                            "operation": "remove",
                            "value": "Metformin",
                        }
                    ]
                }
            )
        )

        self.assertEqual(
            result.candidates[0].operation,
            "remove",
        )

    def test_parses_and_normalizes_scalar_candidate(self):
        result = parse_memory_candidate_extraction(
            json.dumps(
                {
                    "candidates": [
                        {
                            "field": "smoking_status",
                            "operation": "SET",
                            "value": "Former",
                        }
                    ]
                }
            )
        )

        self.assertEqual(
            result.candidates[0],
            MemoryCandidate(
                field="smoking_status",
                operation="set",
                value="former",
            ),
        )

    def test_rejects_invalid_json(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                "not-json"
            )

    def test_rejects_non_object_response(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                '["candidate"]'
            )

    def test_rejects_unexpected_top_level_field(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [],
                        "reasoning": "hidden",
                    }
                )
            )

    def test_rejects_more_than_eight_candidates(self):
        candidates = [
            {
                "field": "allergies",
                "operation": "add",
                "value": f"Allergy {index}",
            }
            for index in range(9)
        ]

        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": candidates,
                    }
                )
            )

    def test_rejects_candidate_with_extra_field(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "allergies",
                                "operation": "add",
                                "value": "Penicillin",
                                "confidence": 0.99,
                            }
                        ]
                    }
                )
            )

    def test_rejects_unsupported_field(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "diagnosis",
                                "operation": "add",
                                "value": "Asthma",
                            }
                        ]
                    }
                )
            )

    def test_rejects_wrong_operation_for_list_field(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "allergies",
                                "operation": "set",
                                "value": "Penicillin",
                            }
                        ]
                    }
                )
            )

    def test_rejects_wrong_operation_for_scalar_field(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "smoking_status",
                                "operation": "add",
                                "value": "current",
                            }
                        ]
                    }
                )
            )

    def test_rejects_non_extractable_scalar_value(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "pregnancy_status",
                                "operation": "set",
                                "value": "unknown",
                            }
                        ]
                    }
                )
            )

    def test_rejects_blank_value(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "allergies",
                                "operation": "add",
                                "value": "   ",
                            }
                        ]
                    }
                )
            )

    def test_rejects_value_longer_than_two_hundred_characters(self):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "allergies",
                                "operation": "add",
                                "value": "A" * 201,
                            }
                        ]
                    }
                )
            )

    def test_rejects_duplicate_list_candidates_case_insensitively(
        self,
    ):
        with self.assertRaises(AIInvalidResponseError):
            parse_memory_candidate_extraction(
                json.dumps(
                    {
                        "candidates": [
                            {
                                "field": "allergies",
                                "operation": "add",
                                "value": "Penicillin",
                            },
                            {
                                "field": "allergies",
                                "operation": "add",
                                "value": "penicillin",
                            },
                        ]
                    }
                )
            )
