# Example profile fixtures

These two fixtures are derived from the held-out test split of the TDD2022 *Theft detection in smart grid environment* dataset (Mendeley Data v3, CC BY 4.0: https://doi.org/10.17632/c3c7329tjj.3).

- `flagged_profile_input.json`: MidriseApartment, day index 34, all 24 hourly labels are synthetic `Theft1`; the model flags it.
- `normal_profile_input.json`: MidriseApartment, day index 30, all 24 hourly labels are `Normal`; the model does not flag it.
- The matching `*_profile_payload.json` files are the exact output of `script/encode_profile.py`, including the fixed-point feature vector and SHA-256 input commitment.

These are reproducible synthetic benchmark examples, not real household meter readings, customer evidence, or field validation. Dataset labels are synthetic pattern injections. The model card documents the performance limits, including low recall on Theft6.
