# Model card â€” Meter Profile Anomaly Screen v1

## Intended use

A small neural classifier executed inside `ReactiveMeterGuard.react()` to screen daily energy-meter profiles and route suspicious profiles to human review. It is a hackathon prototype, not a production fraud detector.

The model output is a screening signal. It must not be used as proof of theft, tampering, meter bypass, or customer wrongdoing.

## Data

**Source:** TDD2022, *Theft detection in smart grid environment*, Mendeley Data version 3.  
**Dataset DOI:** [10.17632/c3c7329tjj.3](https://doi.org/10.17632/c3c7329tjj.3)  
**Licence:** CC BY 4.0.

The publisher describes 16 consumer/building categories and six theft-pattern transformations applied to energy-consumption readings. The six labels are synthetic injections, not field-confirmed incidents.

Dataset audit:
- 560,655 source rows.
- 560,640 valid hourly rows retained.
- 15 malformed extra rows with `Class = 0` excluded.
- 64 annual sequences of 8,760 hours.
- 16 building-use categories, four annual sequences per category.
- The downloaded CSV SHA-256 was recorded in the training artifact.

## Target and features

The target is binary at daily-profile level:
- `0`: all 24 hourly labels for the day are Normal.
- `1`: at least one hourly label for the day is one of the synthetic theft-pattern classes.

For each day, the feature baseline is the median of the previous four same weekdays (days tâˆ’7, tâˆ’14, tâˆ’21 and tâˆ’28). No current-day or future labels are used as inputs.

Ten features, in exact model order:
1. Log ratio of current daily energy to the previous four same-weekday daily totals' median.
2. Fraction of zero-consumption hours.
3. Coefficient of variation.
4. Peak-to-mean ratio.
5. Total-variation distance between normalized current and baseline hourly profiles.
6. Correlation between normalized current and baseline hourly profiles.
7. Total-variation distance to the reversed baseline profile.
8. Correlation to the reversed baseline profile.
9. First-half-of-day log energy ratio.
10. Second-half-of-day log energy ratio.

`script/encode_profile.py` implements the same feature calculations for off-chain meter-profile preparation. Its input is one current 24-hour profile and four prior same-weekday 24-hour baselines. Features are quantized to a 1,000,000 fixed-point scale before submission.

## Evaluation design

The split is grouped by building-use category to avoid putting the same category in both training and held-out sets.

| Split | Building-use categories | Daily profiles |
|---|---|---:|
| Train | 10 categories | 13,480 |
| Validation | 3 categories | 4,044 |
| Test | 3 unseen categories | 4,044 |

Held-out test categories: MidriseApartment, QuickServiceRestaurant and SecondarySchool.

The validation threshold was selected to maximize recall subject to validation false-positive rate â‰¤10%. The resulting probability threshold is 0.225. The test set was not used to select the threshold.

## Results

### Held-out test

| Metric | Neural model |
|---|---:|
| Accuracy | 86.82% |
| Precision | 81.74% |
| Recall | 90.30% |
| F1 | 85.81% |
| False-positive rate | 15.93% |
| Specificity | 84.07% |
| Balanced accuracy | 87.19% |

### Simple rule baseline

| Metric | Rule baseline |
|---|---:|
| Accuracy | 75.52% |
| Precision | 70.09% |
| Recall | 77.63% |
| F1 | 73.67% |
| False-positive rate | 26.15% |

### Recall by synthetic label on held-out test

| Label | Samples | Recall |
|---|---:|---:|
| Theft1 | 374 | 92.51% |
| Theft2 | 255 | 100.00% |
| Theft3 | 299 | 100.00% |
| Theft4 | 289 | 100.00% |
| Theft5 | 218 | 99.08% |
| Theft6 | 250 | 42.80% |
| Mixed labels | 99 | 100.00% |

Normal profiles: 2,260 samples; false-positive rate 15.93%.

**Important limitation:** Theft6 recall is poor. The current daily-profile feature set does not reliably identify that synthetic pattern. This must be disclosed and must not be hidden by the aggregate score.

## On-chain implementation

- Architecture: 10 inputs â†’ 8 ReLU hidden units â†’ 1 logit.
- Weights and preprocessing parameters quantized to 1e6 fixed point.
- Validation probability threshold: 0.225; corresponding quantized logit cutoff: âˆ’1.236763.
- Python fixed-point parity: 500 sampled held-out profiles, 100% prediction parity; maximum sampled logit error 0.0000605.
- Solidity parity test: passed for the checked vector.
- Solidity model inference: 67,499 gas in the local Foundry harness.
- Full local `react()` + model + event-only callback request: 130,227 gas.

Gas figures are local EVM measurements using a mock system contract. They are not live Reactive Network execution costs.

## Example fixtures

The repository includes two derived examples from the held-out test split:
- `examples/flagged_profile_input.json`: a pure synthetic Theft1 daily profile that the model flags.
- `examples/normal_profile_input.json`: a Normal daily profile that the model does not flag.

These demonstrate feature extraction and model routing on held-out synthetic data; they are not real household meter readings or field validation.

## Known limitations and risks

1. **Synthetic labels:** the benchmark does not establish field performance or real theft-detection capability.
2. **Theft6:** recall is only 42.8% on the held-out categories.
3. **False positives:** 15.93% of normal held-out daily profiles were flagged. Human review is mandatory.
4. **Domain coverage:** the dataset is simulated building energy data, not a representative sample of community microgrids in production.
5. **Feature provenance:** the meter signs the submitted feature vector in its origin-chain transaction, but the origin contract does not independently recompute the features from the raw profile. The profile hash is a SHA-256 commitment to canonical input, not proof of correct feature extraction.
6. **Temporal scope:** the model screens daily profiles against historical same-weekday baselines; it is not a real-time hourly detector.
7. **Operational scope:** synthetic testnet execution does not establish field model performance, operating costs, or production callback reliability.
8. **Review routing:** the prototype additionally holds profiles within 0.25 logit of the model cutoff or outside the standardized clipping range (±4). These routing rules have not been calibrated to an operator’s review budget.

## Callback and settlement safety

- The callback requires the authorized Base Sepolia proxy and its injected Reactive contract address. Callback fee payments can use only the balance above settlement principal.
- Tests reject a direct EOA attempting to forge a callback and reject a legitimate proxy carrying an unapproved Reactive sender.
- A flag means `HOLD_FOR_REVIEW`, never automatic punishment.
- A held settlement requires an authorized human reviewer and a nonzero evidence hash before it can become releasable.
- All payouts require a separate human release transaction. The Reactive owner can pause and resume the subscription.
- No automatic disconnection, fines, seizure, public accusation, or irreversible action.
- Raw household consumption series are kept off-chain.

## Reproduction

Install Python development dependency:

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s test -p "test_feature_encoder.py" -v
```

Run the Solidity tests with Foundry:

```powershell
forge test -vv
```

