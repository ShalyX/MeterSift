#!/usr/bin/env python3
"""Build the exact 10-feature, 1e6-fixed-point payload accepted by MeterProfileOrigin.

Input JSON:
{
  "meter": "0x...40 hex chars...",
  "sequence": 1,
  "current": [24 hourly kW readings],
  "baseline_days": [
    [24 readings from 28 days before],
    [24 readings from 21 days before],
    [24 readings from 14 days before],
    [24 readings from 7 days before]
  ]
}
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import numpy as np

SCALE = 1_000_000
EPS = 1e-8
FEATURE_ORDER = [
    "log_energy_ratio_same_weekday_4w",
    "zero_hour_fraction",
    "coefficient_of_variation",
    "peak_to_mean",
    "profile_total_variation",
    "profile_correlation",
    "reverse_profile_tv",
    "reverse_profile_correlation",
    "first_half_log_ratio",
    "second_half_log_ratio",
]


def _profile(values: object, name: str) -> np.ndarray:
    arr = np.asarray(values, dtype=np.float64)
    if arr.shape != (24,):
        raise ValueError(f"{name} must contain exactly 24 hourly readings")
    if not np.isfinite(arr).all():
        raise ValueError(f"{name} contains NaN or infinite readings")
    if np.any(arr < 0):
        raise ValueError(f"{name} contains negative energy readings")
    return arr


def extract_features(current: object, baseline_days: object) -> np.ndarray:
    """Mirror train_spike_v4.py feature calculations in their exact order."""
    cur = _profile(current, "current")
    prev = np.asarray(baseline_days, dtype=np.float64)
    if prev.shape != (4, 24):
        raise ValueError("baseline_days must be exactly 4 profiles × 24 hourly readings")
    if not np.isfinite(prev).all():
        raise ValueError("baseline_days contains NaN or infinite readings")
    if np.any(prev < 0):
        raise ValueError("baseline_days contains negative energy readings")

    base_total = float(np.median(prev.sum(axis=1)))
    cur_total = float(cur.sum())
    base = np.median(prev, axis=0)
    base_total_profile = float(base.sum())

    ratio = float(np.log((cur_total + EPS) / (base_total + EPS)))
    mean = float(cur.mean())
    cv = float(cur.std() / (mean + EPS))
    zero_frac = float(np.mean(cur <= 1e-7))
    peak_ratio = float(cur.max() / (mean + EPS))

    a = cur / (cur_total + EPS)
    b = base / (base_total_profile + EPS)
    tv = float(0.5 * np.abs(a - b).sum())

    ac, bc = a - a.mean(), b - b.mean()
    denom = float(np.linalg.norm(ac) * np.linalg.norm(bc))
    corr = float(np.dot(ac, bc) / denom) if denom > 1e-10 else 0.0

    rev = base[::-1] / (base_total_profile + EPS)
    tv_rev = float(0.5 * np.abs(a - rev).sum())
    rc = rev - rev.mean()
    rden = float(np.linalg.norm(ac) * np.linalg.norm(rc))
    corr_rev = float(np.dot(ac, rc) / rden) if rden > 1e-10 else 0.0

    first_ratio = float(np.log((cur[:12].sum() + EPS) / (base[:12].sum() + EPS)))
    second_ratio = float(np.log((cur[12:].sum() + EPS) / (base[12:].sum() + EPS)))

    features = np.asarray(
        [ratio, zero_frac, cv, peak_ratio, tv, corr, tv_rev, corr_rev, first_ratio, second_ratio],
        dtype=np.float64,
    )
    if not np.isfinite(features).all():
        raise ValueError("feature extraction produced a non-finite value")
    return features


def build_payload(data: dict) -> dict:
    meter = data.get("meter", "")
    if not isinstance(meter, str) or not re.fullmatch(r"0x[0-9a-fA-F]{40}", meter):
        raise ValueError("meter must be a 20-byte 0x-prefixed EVM address")
    sequence = data.get("sequence")
    if not isinstance(sequence, int) or isinstance(sequence, bool) or not (1 <= sequence < 2**64):
        raise ValueError("sequence must be an integer from 1 through 2^64-1")

    current = _profile(data.get("current"), "current")
    baseline = np.asarray(data.get("baseline_days"), dtype=np.float64)
    features = extract_features(current, baseline)
    scaled = np.rint(features * SCALE).astype(np.int64)

    canonical = {
        "version": 1,
        "meter": meter.lower(),
        "sequence": sequence,
        "current": current.tolist(),
        "baseline_days": baseline.tolist(),
    }
    encoded = json.dumps(canonical, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    profile_hash = "0x" + hashlib.sha256(encoded).hexdigest()

    return {
        "profileHash": profile_hash,
        "meter": meter,
        "sequence": sequence,
        "scale": SCALE,
        "featureOrder": FEATURE_ORDER,
        "featuresFloat": [float(x) for x in features],
        "features": [int(x) for x in scaled],
        "provenance": "SHA-256 commitment to canonical profile input; not an attestation of truthful meter readings",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="JSON profile input file")
    parser.add_argument("-o", "--output", type=Path, help="write output JSON to this path")
    args = parser.parse_args()

    data = json.loads(args.input.read_text(encoding="utf-8"))
    result = build_payload(data)
    rendered = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
