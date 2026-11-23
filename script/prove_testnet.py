"""Deploy a fresh testnet instance and record both funded operator journeys."""

import argparse
import json
import os
import secrets
import subprocess
import tempfile
import time
from pathlib import Path

from operator_flow import (
    BASE_CHAIN, BASE_RPC, call, case_id, cast, check_chain, evidence,
    inspect_profile, prepare_case, run_action, send, status, verify_address,
)

ROOT = Path(__file__).resolve().parent.parent
LASNA_CHAIN = 5318007
LASNA_RPC = "https://lasna-rpc.rnk.dev/"
SYSTEM = "0x8888888888888888888888888888888888888888"
PROXY = "0x476F44b11F5C942c58f4c8E3d0300E5710743585"
BASE_OPERATOR_BUDGET = 10**15
LASNA_OPERATOR_BUDGET = 15 * 10**17
REACTIVE_RESERVE = 3 * 10**17
CALLBACK_RESERVE = 10**14
METER_GAS = 5 * 10**13
PRINCIPAL = 10**13


def deploy(rpc, chain, contract, wallet, *args):
    check_chain(rpc, chain)
    command = [
        "forge", "create", f"src/{contract}.sol:{contract}", "--rpc-url", rpc,
        "--broadcast", "--json", *wallet,
    ]
    if args:
        command.extend(("--constructor-args", *map(str, args)))
    result = json.loads(subprocess.check_output(command, text=True, encoding="utf-8"))
    verify_address(result["deployedTo"])
    receipt = json.loads(cast("receipt", result["transactionHash"], "--rpc-url", rpc, "--json"))
    if int(receipt["status"], 16) != 1 or receipt["contractAddress"].lower() != result["deployedTo"].lower():
        raise RuntimeError(f"Deployment failed for {contract}")
    return result["deployedTo"], receipt


def block_number(rpc):
    return int(cast("block-number", "--rpc-url", rpc, "--rpc-timeout", "15"))


def event(rpc, address, topic, start, commitment, topic_index, deadline=100):
    stop = time.monotonic() + deadline
    while time.monotonic() < stop:
        end = block_number(rpc)
        for first in range(start, end + 1, 180):
            last = min(first + 179, end)
            logs = json.loads(cast("logs", topic, "--address", address, "--from-block", first,
                                   "--to-block", last, "--rpc-url", rpc, "--rpc-timeout", "15", "--json"))
            for log in logs:
                if log["topics"][topic_index].lower() == commitment.lower():
                    return log
        start = end + 1
        time.sleep(2)
    raise RuntimeError(f"Timed out waiting for {topic} on {rpc}")


def actor(directory, name, password, password_file):
    subprocess.run(
        ["cast", "wallet", "new", str(directory), name], check=True, stdout=subprocess.DEVNULL,
        env={**os.environ, "CAST_PASSWORD": password},
    )
    wallet = ("--keystore", str(directory / name), "--password-file", str(password_file))
    return verify_address(cast("wallet", "address", *wallet)), wallet


def protect_demo_password(directory, password):
    # Only the current Windows user can recover the disposable demo accounts.
    blob = subprocess.check_output(
        ["pwsh", "-NoProfile", "-Command",
         "ConvertFrom-SecureString (ConvertTo-SecureString ([Console]::ReadLine()) -AsPlainText -Force)"],
        input=password + "\n", text=True, encoding="utf-8",
    ).strip()
    (directory / "password.dpapi").write_text(blob, encoding="ascii")


def restore_demo_password(directory):
    return subprocess.check_output(
        ["pwsh", "-NoProfile", "-Command",
         "ConvertFrom-SecureString (ConvertTo-SecureString ([Console]::ReadLine())) -AsPlainText"],
        input=(directory / "password.dpapi").read_text(encoding="ascii") + "\n",
        text=True, encoding="utf-8",
    ).strip()


def save_proof(directory, proof):
    target = directory / "proof.json"
    pending = target.with_suffix(".tmp")
    pending.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    pending.replace(target)


def record_step(directory, proof, name, receipt, chain=BASE_CHAIN):
    proof["steps"][name] = {
        "chain": chain, "hash": receipt["transactionHash"], "block": int(receipt["blockNumber"], 16),
    }
    save_proof(directory, proof)
    print(f"{name}: {receipt['transactionHash']}", flush=True)


def review_flagged(directory, proof, signer):
    case_proof = proof["cases"]["flagged"]
    case, identifier = case_proof["case"], case_proof["settlementId"]
    origin, escrow = (proof["contracts"][name] for name in ("origin", "escrow"))
    current = status(BASE_RPC, escrow, identifier)
    if current["status"] == "HOLD_FOR_REVIEW" and current["amountWei"] == PRINCIPAL:
        fixture = ROOT / "examples" / "flagged_profile_input.json"
        print("\nFlagged synthetic daily profile is held with funded principal.", flush=True)
        print(json.dumps(current, indent=2), flush=True)
        print(json.dumps(inspect_profile(case, fixture), indent=2), flush=True)
        print(f"Source profile: {fixture}", flush=True)
        notes = ""
        while not notes:
            notes = input("Enter review notes to approve this synthetic case, or type HOLD to leave it pending: ").strip()
        if notes == "HOLD":
            raise RuntimeError("Operator chose to leave the case held.")
        evidence_file = directory / "flagged-review.json"
        evidence_file.write_text(json.dumps({
            "settlementId": identifier,
            "notes": notes,
            "profileHash": case["profileHash"],
            "origin": proof["steps"]["flagged_origin"]["hash"],
            "policy": "synthetic demo",
        }, indent=2) + "\n", encoding="utf-8")
        approved = run_action("approve", BASE_RPC, origin, escrow, case, signer, evidence_path=evidence_file)
        case_proof["approved"] = status(BASE_RPC, escrow, identifier)
        if case_proof["approved"]["evidenceHash"] != evidence(evidence_file, identifier):
            raise RuntimeError("Approved evidence commitment does not match the local record.")
        record_step(directory, proof, "flagged_approval", approved)
        current = case_proof["approved"]
    if current["status"] != "REVIEW_APPROVED" or current["amountWei"] != PRINCIPAL:
        raise RuntimeError(f"Expected a funded approved case. Current status: {current['status']}")
    before = balance(BASE_RPC, case["meter"])
    released = run_action("release", BASE_RPC, origin, escrow, case, signer)
    case_proof["released"] = status(BASE_RPC, escrow, identifier)
    case_proof["recipientBalanceIncreaseWei"] = balance(BASE_RPC, case["meter"]) - before
    if (case_proof["released"]["status"], case_proof["released"]["amountWei"],
            case_proof["recipientBalanceIncreaseWei"]) != ("RELEASED", 0, PRINCIPAL):
        raise RuntimeError("Flagged release did not match the funded principal.")
    record_step(directory, proof, "flagged_release", released)


def finish_proof(directory, proof):
    guard, escrow = (proof["contracts"][name] for name in ("reactive", "escrow"))
    proof["principalRemainingWei"] = int(call(BASE_RPC, escrow, "totalPrincipal()"), 16)
    proof["reactiveDebtWei"] = int(call(LASNA_RPC, SYSTEM, "debt(address)", guard), 16)
    proof["callbackDebtWei"] = int(call(BASE_RPC, PROXY, "debt(address)", escrow), 16)
    if any(proof[key] for key in ("principalRemainingWei", "reactiveDebtWei", "callbackDebtWei")):
        raise RuntimeError("Unexpected remaining principal or debt")
    proof["complete"] = True
    save_proof(directory, proof)
    print(f"Both funded paths verified: {directory / 'proof.json'}", flush=True)


def resume_review(directory):
    check_chain(BASE_RPC, BASE_CHAIN)
    check_chain(LASNA_RPC, LASNA_CHAIN)
    proof = json.loads((directory / "proof.json").read_text(encoding="utf-8"))
    if proof.get("complete") or not {"normal_release", "flagged_callback"} <= proof["steps"].keys():
        raise RuntimeError("There is no saved funded review to resume.")
    actor_directory = directory / "local-demo-wallets"
    with tempfile.TemporaryDirectory(dir=directory) as ephemeral:
        password_file = Path(ephemeral) / "demo-password"
        password_file.write_text(restore_demo_password(actor_directory), encoding="ascii")
        signer = ("--keystore", str(actor_directory / "operator"), "--password-file", str(password_file))
        if verify_address(cast("wallet", "address", *signer)) != proof["operator"].lower():
            raise RuntimeError("The recovered operator does not own this deployment.")
        review_flagged(directory, proof, signer)
        finish_proof(directory, proof)


def balance(rpc, address):
    return int(cast("balance", address, "--rpc-url", rpc, "--rpc-timeout", "15"))


def fund_demo_wallet(rpc, chain, account, address, amount, label):
    print(f"Unlock {account} to send {label} testnet funds to {address}.", flush=True)
    return send(rpc, address, None, wallet=("--account", account), value=amount, expected_chain=chain)


def run(directory, account):
    check_chain(BASE_RPC, BASE_CHAIN)
    check_chain(LASNA_RPC, LASNA_CHAIN)
    proof = {"chains": {"baseSepolia": BASE_CHAIN, "lasna": LASNA_CHAIN}, "steps": {}}

    def record(name, receipt, chain=BASE_CHAIN):
        record_step(directory, proof, name, receipt, chain)

    with tempfile.TemporaryDirectory(dir=directory) as ephemeral:
        temp = Path(ephemeral)
        actor_directory = directory / "local-demo-wallets"
        actor_directory.mkdir()
        passwords = secrets.token_hex(32)
        protect_demo_password(actor_directory, passwords)
        password_file = temp / "demo-password"
        password_file.write_text(passwords, encoding="ascii")
        owner, signer = actor(actor_directory, "operator", passwords, password_file)
        meter, meter_signer = actor(actor_directory, "meter", passwords, password_file)
        proof["operator"] = owner
        proof["meter"] = meter
        record("base_operator_funding", fund_demo_wallet(
            BASE_RPC, BASE_CHAIN, account, owner, BASE_OPERATOR_BUDGET, "0.001 Base Sepolia ETH",
        ))
        record("lasna_operator_funding", fund_demo_wallet(
            LASNA_RPC, LASNA_CHAIN, account, owner, LASNA_OPERATOR_BUDGET, "1.5 Lasna lREACT",
        ), LASNA_CHAIN)
        record("meter_gas", send(BASE_RPC, meter, None, wallet=signer, value=METER_GAS))
        origin, receipt = deploy(BASE_RPC, BASE_CHAIN, "MeterProfileOrigin", signer)
        record("deploy_origin", receipt)
        guard, receipt = deploy(LASNA_RPC, LASNA_CHAIN, "ReactiveMeterGuard", signer, BASE_CHAIN, origin, BASE_CHAIN)
        record("deploy_guard", receipt, LASNA_CHAIN)
        escrow, receipt = deploy(BASE_RPC, BASE_CHAIN, "SettlementEscrow", signer, PROXY, guard, owner)
        proof["contracts"] = {"origin": origin, "reactive": guard, "escrow": escrow}
        record("deploy_escrow", receipt)
        record("authorize_meter", send(BASE_RPC, origin, "setMeterAuthorization(address,bool)", meter, "true", wallet=signer))
        record("reactive_reserves", send(LASNA_RPC, SYSTEM, "depositTo(address)", guard, wallet=signer,
                                         value=REACTIVE_RESERVE, expected_chain=LASNA_CHAIN), LASNA_CHAIN)
        record("callback_reserves", send(BASE_RPC, PROXY, "depositTo(address)", escrow, wallet=signer, value=CALLBACK_RESERVE))
        record("set_escrow", send(LASNA_RPC, guard, "setSettlementEscrow(address)", escrow,
                                  wallet=signer, expected_chain=LASNA_CHAIN), LASNA_CHAIN)
        record("activate", send(LASNA_RPC, guard, "activate()", wallet=signer, expected_chain=LASNA_CHAIN), LASNA_CHAIN)

        proof["cases"] = {}
        for sequence, name, expected in ((1, "normal", "RELEASE_READY"), (2, "flagged", "HOLD_FOR_REVIEW")):
            case = prepare_case(ROOT / "examples" / f"{name}_profile_input.json", meter, sequence)
            case_file = directory / f"{name}.json"
            case_file.write_text(json.dumps(case, indent=2) + "\n", encoding="utf-8")
            identifier = case_id(BASE_RPC, escrow, case)
            case_proof = proof["cases"][name] = {"case": case, "settlementId": identifier}
            funded = run_action("fund", BASE_RPC, origin, escrow, case, signer, PRINCIPAL)
            record(f"{name}_deposit", funded)
            assert status(BASE_RPC, escrow, identifier)["amountWei"] == PRINCIPAL
            start = block_number(LASNA_RPC)
            if name == "flagged":
                record("pause_for_recovery_demo", send(LASNA_RPC, guard, "deactivate()", wallet=signer,
                                                     expected_chain=LASNA_CHAIN), LASNA_CHAIN)
            submitted = run_action("submit", BASE_RPC, origin, escrow, case, meter_signer)
            record(f"{name}_origin", submitted)
            if name == "flagged":
                case_proof["beforeRetry"] = status(BASE_RPC, escrow, identifier)
                assert case_proof["beforeRetry"]["status"] == "PENDING"
                record("resume_for_recovery_demo", send(LASNA_RPC, guard, "activate()", wallet=signer,
                                                       expected_chain=LASNA_CHAIN), LASNA_CHAIN)
                retried = run_action("retry", BASE_RPC, origin, escrow, case, signer)
                record("flagged_retry_origin", retried)
            decision = event(
                LASNA_RPC, guard, "DecisionEvaluated(address,uint64,bytes32,bool,int256,uint32)",
                start, case["profileHash"], 3,
            )
            record(f"{name}_reactive", json.loads(cast(
                "receipt", decision["transactionHash"], "--rpc-url", LASNA_RPC, "--json",
            )), LASNA_CHAIN)
            callback = event(
                BASE_RPC, escrow, "DecisionRecorded(bytes32,address,uint64,uint8,int256,uint32)",
                int(submitted["blockNumber"], 16), case["profileHash"], 1,
            )
            callback_receipt = json.loads(cast("receipt", callback["transactionHash"], "--rpc-url", BASE_RPC, "--json"))
            assert int(callback_receipt["status"], 16) == 1 and callback_receipt["to"].lower() == PROXY.lower()
            case_proof["routed"] = status(BASE_RPC, escrow, identifier)
            assert case_proof["routed"]["status"] == expected
            assert case_proof["routed"]["amountWei"] == PRINCIPAL
            if name == "flagged":
                attempt = call(LASNA_RPC, guard, "lastReplayAttempt(bytes32)", identifier)
                assert int(attempt, 16) == 1
            record(f"{name}_callback", callback_receipt)

            if name == "flagged":
                review_flagged(directory, proof, signer)
                continue

            before = balance(BASE_RPC, meter)
            released = run_action("release", BASE_RPC, origin, escrow, case, signer)
            case_proof["released"] = status(BASE_RPC, escrow, identifier)
            case_proof["recipientBalanceIncreaseWei"] = balance(BASE_RPC, meter) - before
            assert case_proof["released"]["status"] == "RELEASED" and case_proof["released"]["amountWei"] == 0
            assert case_proof["recipientBalanceIncreaseWei"] == PRINCIPAL
            record(f"{name}_release", released)

        finish_proof(directory, proof)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--account", default=os.environ.get("FOUNDRY_ACCOUNT"), help="Local Foundry account funding the testnet demo wallets")
    parser.add_argument("--output", type=Path, required=True, help="Empty local proof directory")
    parser.add_argument("--resume-review", action="store_true", help="Resume review from an existing proof directory")
    args = parser.parse_args()
    if not args.resume_review and not args.account:
        parser.error("Pass --account or set FOUNDRY_ACCOUNT to a locally configured Foundry account alias; no default account is assumed.")
    if os.name != "nt":
        parser.error("This proof runner requires Windows DPAPI for the local demo wallets.")
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    if not args.resume_review and any(directory.iterdir()):
        parser.error("proof directory must be empty")
    os.chdir(ROOT)
    try:
        if args.resume_review:
            resume_review(directory)
        else:
            run(directory, args.account)
        (directory / "failure.txt").unlink(missing_ok=True)
    except Exception as error:
        (directory / "failure.txt").write_text(str(error) + "\n", encoding="utf-8")
        raise


if __name__ == "__main__":
    main()
