import json
import math
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "script"))
from encode_profile import SCALE, build_payload, extract_features


class FeatureEncoderTests(unittest.TestCase):
    def setUp(self):
        self.base = np.asarray(
            [[0.2 + ((h % 24) / 24) for h in range(24)] for _ in range(4)],
            dtype=np.float64,
        )
        self.current = self.base[0].copy()

    def test_identical_profile_has_zero_energy_and_shape_distance(self):
        f = extract_features(self.current, self.base)
        self.assertAlmostEqual(f[0], 0.0, places=7)
        self.assertAlmostEqual(f[4], 0.0, places=7)
        self.assertAlmostEqual(f[5], 1.0, places=7)

    def test_payload_is_fixed_point_and_deterministic(self):
        data = {
            "meter": "0x3333333333333333333333333333333333333333",
            "sequence": 7,
            "current": self.current.tolist(),
            "baseline_days": self.base.tolist(),
        }
        a = build_payload(data)
        b = build_payload(data)
        self.assertEqual(a, b)
        self.assertEqual(a["scale"], SCALE)
        self.assertEqual(len(a["features"]), 10)
        self.assertTrue(all(isinstance(x, int) for x in a["features"]))
        self.assertEqual(len(a["profileHash"]), 66)

    def test_hash_changes_when_sequence_changes(self):
        data = {
            "meter": "0x3333333333333333333333333333333333333333",
            "sequence": 7,
            "current": self.current.tolist(),
            "baseline_days": self.base.tolist(),
        }
        a = build_payload(data)
        data["sequence"] = 8
        b = build_payload(data)
        self.assertNotEqual(a["profileHash"], b["profileHash"])

    def test_public_example_payloads_match_encoder(self):
        examples = ROOT / "examples"
        for name in ("flagged", "normal"):
            with self.subTest(name=name):
                data = json.loads((examples / f"{name}_profile_input.json").read_text(encoding="utf-8"))
                expected = json.loads((examples / f"{name}_profile_payload.json").read_text(encoding="utf-8"))
                actual = build_payload(data)
                exact_fields = (
                    "profileHash",
                    "meter",
                    "sequence",
                    "scale",
                    "featureOrder",
                    "features",
                    "provenance",
                )
                for field in exact_fields:
                    self.assertEqual(actual[field], expected[field], msg=f"{name}: {field}")

                self.assertEqual(len(actual["featuresFloat"]), len(expected["featuresFloat"]))
                for index, (actual_value, expected_value) in enumerate(
                    zip(actual["featuresFloat"], expected["featuresFloat"])
                ):
                    self.assertTrue(
                        math.isclose(actual_value, expected_value, rel_tol=1e-12, abs_tol=1e-12),
                        msg=(
                            f"{name}: featuresFloat[{index}] differs beyond floating-point "
                            f"tolerance: actual={actual_value!r}, expected={expected_value!r}"
                        ),
                    )

    def test_rejects_incomplete_baseline(self):
        with self.assertRaises(ValueError):
            extract_features(self.current, self.base[:3])

    def test_rejects_nonfinite_reading(self):
        broken = self.current.copy()
        broken[4] = float("nan")
        with self.assertRaises(ValueError):
            extract_features(broken, self.base)


if __name__ == "__main__":
    unittest.main()
