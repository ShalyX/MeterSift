"""Operate a Meter Settlement Guard deployment on Base Sepolia."""

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

BASE_RPC = "https://sepolia.base.org"
BASE_CHAIN = 84532
STATUSES = (
    "NONE", "PENDING", "RELEASE_READY", "HOLD_FOR_REVIEW",
    "REVIEW_APPROVED", "RELEASED", "REFUNDED",
)


def cast(*args):
    return subprocess.check_output(["cast", *map(str, args)], text=True, encoding="utf-8").strip()


def check_chain(rpc, expected):
    if int(cast("chain-id", "--rpc-url", rpc, "--rpc-timeout", "15")) != expected:
        raise ValueError(f"RPC must be chain {expected}")


def call(rpc, contract, signature, *args):
    return cast("call", contract, signature, *args, "--rpc-url", rpc, "--rpc-timeout", "15")


def send(rpc, target, signature, *args, wallet, value=None, expected_chain=BASE_CHAIN):
    check_chain(rpc, expected_chain)
    value_option = ["--value", str(value)] if value is not None else []
    calldata = [signature, *args] if signature else []
    receipt = json.loads(cast(
        "send", target, *calldata, *value_option, *wallet,
        "--rpc-url", rpc, "--rpc-timeout", "30", "--json",
    ))
    if int(receipt["status"], 16) != 1:
        raise RuntimeError(f"Transaction failed: {receipt['transactionHash']}")
    return receipt


def verify_address(value):
    if not re.fullmatch(r"0x[0-9a-fA-F]{40}", value or "") or int(value, 16) == 0:
        raise ValueError("Expected a nonzero EVM address")
    return value.lower()


def prepare_case(profile_file, meter=None, sequence=None):
    return prepare_profile(json.loads(profile_file.read_text(encoding="utf-8-sig")), meter, sequence)


def prepare_profile(profile, meter, sequence):
    from encode_profile import build_payload

    if not isinstance(profile, dict):
        raise ValueError("Expected a JSON profile object")
    if meter is not None:
        profile["meter"] = meter
    if sequence is not None:
        profile["sequence"] = sequence
    profile["meter"] = verify_address(profile["meter"])
    payload = build_payload(profile)
    return validate_case({key: payload[key] for key in ("meter", "sequence", "profileHash", "features")})


def load_case(path):
    return validate_case(json.loads(path.read_text(encoding="utf-8-sig")))


def validate_case(case):
    if not isinstance(case, dict):
        raise ValueError("Expected a JSON case object")
    case["meter"] = verify_address(case.get("meter"))
    sequence, profile_hash, features = (case[key] for key in ("sequence", "profileHash", "features"))
    if type(sequence) is not int or not 0 < sequence < 2**64:
        raise ValueError("Invalid case sequence")
    if not isinstance(profile_hash, str) or not re.fullmatch(r"0x[0-9a-fA-F]{64}", profile_hash):
        raise ValueError("Invalid profile commitment")
    if int(profile_hash, 16) == 0:
        raise ValueError("Invalid profile commitment")
    if not isinstance(features, list) or len(features) != 10:
        raise ValueError("Case must contain ten valid fixed-point features")
    if any(type(x) is not int or abs(x) > 100_000_000 for x in features):
        raise ValueError("Case must contain ten valid fixed-point features")
    return {"meter": case["meter"], "sequence": sequence, "profileHash": profile_hash.lower(), "features": features}


def coordinates(case):
    return case["meter"], case["sequence"], case["profileHash"]


def feature_arg(case):
    return "[" + ",".join(map(str, case["features"])) + "]"


def case_id(rpc, escrow, case):
    result = call(rpc, escrow, "settlementId(address,uint64,bytes32)", *coordinates(case))
    if not re.fullmatch(r"0x[0-9a-fA-F]{64}", result):
        raise RuntimeError("Escrow did not return a settlement ID. Check the deployment address.")
    return result


def status(rpc, escrow, identifier):
    raw = bytes.fromhex(call(rpc, escrow, "settlements(bytes32)", identifier)[2:])
    if len(raw) != 8 * 32:
        raise RuntimeError("Escrow returned an invalid settlement record")
    fields = [raw[i:i + 32] for i in range(0, len(raw), 32)]
    numbers = [int.from_bytes(field, "big") for field in fields]
    return {
        "settlementId": identifier,
        "meter": "0x" + fields[0][-20:].hex(),
        "sequence": numbers[1],
        "amountWei": numbers[2],
        "status": STATUSES[numbers[3]],
        "logitQ": int.from_bytes(fields[4], "big", signed=True),
        "modelVersion": numbers[5],
        "evidenceHash": "0x" + fields[6].hex(),
        "decisionRecorded": bool(numbers[7]),
    }


def read_evidence(path, identifier):
    raw = path.read_bytes()
    record = json.loads(raw)
    if record.get("settlementId", "").lower() != identifier.lower():
        raise ValueError("Evidence belongs to a different settlement")
    if not isinstance(record.get("notes"), str) or not record["notes"].strip():
        raise ValueError("Evidence needs the operator's review notes")
    return record, "0x" + hashlib.sha256(raw).hexdigest()


def evidence(path, identifier):
    return read_evidence(path, identifier)[1]


def inspect_profile(case, path):
    profile = json.loads(path.read_text(encoding="utf-8-sig"))
    rebuilt = prepare_profile(profile, case["meter"], case["sequence"])
    if rebuilt != case:
        raise ValueError("Source readings do not reproduce the case commitment and features")
    current = [float(reading) for reading in profile["current"]]
    return {
        "profileHash": case["profileHash"],
        "currentTotalKwh": sum(current),
        "baselineTotalsKwh": [sum(map(float, day)) for day in profile["baseline_days"]],
        "currentPeakKw": max(current),
    }


def run_action(action, rpc, origin, escrow, case, wallet=(), value=None, evidence_path=None):
    if action == "submit":
        return send(rpc, origin, "submitProfile(uint64,bytes32,int256[10])",
                    case["sequence"], case["profileHash"], feature_arg(case), wallet=wallet)
    if action == "retry":
        return send(rpc, origin, "retryProfile(address,uint64,bytes32,int256[10])",
                    *coordinates(case), feature_arg(case), wallet=wallet)
    if action == "fund":
        return send(rpc, escrow, "deposit(address,uint64,bytes32)",
                    *coordinates(case), value=value, wallet=wallet)
    identifier = case_id(rpc, escrow, case)
    if action == "status":
        return status(rpc, escrow, identifier)
    if action in ("approve", "reject"):
        method = "approveHeldSettlement" if action == "approve" else "rejectHeldSettlement"
        return send(rpc, escrow, f"{method}(bytes32,bytes32)", identifier,
                    evidence(evidence_path, identifier), wallet=wallet)
    method = {"release": "release", "refund": "refundUndelivered"}[action]
    return send(rpc, escrow, f"{method}(bytes32)", identifier, wallet=wallet)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=(
        "prepare", "status", "fund", "submit", "retry", "inspect-profile", "inspect-evidence",
        "approve", "reject", "release", "refund",
    ))
    parser.add_argument("file", type=Path, help="Raw profile for prepare, prepared case for all other actions")
    parser.add_argument("--meter")
    parser.add_argument("--sequence", type=int)
    parser.add_argument("--rpc", default=os.getenv("BASE_SEPOLIA_RPC_URL", BASE_RPC))
    parser.add_argument("--origin", default=os.getenv("ORIGIN_CONTRACT_ADDRESS"))
    parser.add_argument("--escrow", default=os.getenv("SETTLEMENT_ESCROW_ADDRESS"))
    parser.add_argument("--account", default=os.getenv("FOUNDRY_ACCOUNT"))
    parser.add_argument("--wei", type=int)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--output", type=Path, help="Write a new prepared case file")
    args = parser.parse_args()

    if args.action == "prepare":
        result = prepare_case(args.file, args.meter, args.sequence)
        if args.output is not None:
            with args.output.open("x", encoding="utf-8") as output:
                json.dump(result, output, indent=2)
                output.write("\n")
    elif args.action == "inspect-profile":
        if args.profile is None:
            parser.error("inspect-profile requires --profile")
        result = inspect_profile(load_case(args.file), args.profile)
    else:
        case = load_case(args.file)
        check_chain(args.rpc, BASE_CHAIN)
        if args.action in ("submit", "retry"):
            verify_address(args.origin)
        else:
            verify_address(args.escrow)
        if args.action == "fund" and (args.wei is None or args.wei <= 0):
            parser.error("fund requires a positive --wei")
        if args.action in ("inspect-evidence", "approve", "reject") and args.evidence is None:
            parser.error("evidence actions require --evidence")
        if args.action == "inspect-evidence":
            identifier = case_id(args.rpc, args.escrow, case)
            record, digest = read_evidence(args.evidence, identifier)
            result = {
                "evidenceHash": digest,
                "matchesEscrow": status(args.rpc, args.escrow, identifier)["evidenceHash"] == digest,
                "record": record,
            }
        else:
            if args.action != "status" and not args.account:
                parser.error("write actions require --account")
            if args.action == "submit":
                signer = verify_address(cast("wallet", "address", "--account", args.account))
                if signer != case["meter"]:
                    parser.error(f"Signer must match case meter {case['meter']}")
            wallet = ("--account", args.account) if args.account else ()
            result = run_action(
                args.action, args.rpc, args.origin, args.escrow, case, wallet, args.wei, args.evidence,
            )
            if "transactionHash" in result:
                result = {key: result[key] for key in ("transactionHash", "status", "blockNumber")}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
