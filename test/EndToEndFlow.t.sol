// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {MeterProfileOrigin} from "../src/MeterProfileOrigin.sol";
import {ReactiveMeterGuard} from "../src/ReactiveMeterGuard.sol";
import {SettlementEscrow} from "../src/SettlementEscrow.sol";

contract MockSystemE2E {
    uint256 public subscribeCount;
    uint256 public callbackCount;
    uint256 public callbackChainId;
    address public callbackRecipient;
    uint64 public callbackGasLimit;
    bytes public callbackPayload;

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        subscribeCount++;
    }

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory c) external {
        callbackCount++;
        callbackChainId = c.chainId;
        callbackRecipient = c.recipient;
        callbackGasLimit = c.gasLimit;
        callbackPayload = c.payload;
    }
}

contract EndToEndFlowTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address internal constant CALLBACK_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;
    address internal constant METER = address(0x3333);
    address internal constant REVIEWER = address(0x9999);
    uint256 internal constant ORIGIN_CHAIN = 84532;
    bytes32 internal constant FLAGGED_HASH = 0xc6354bb13cc510fd0e0121029ac2821bc32b0166230dfa0cf232e982d9c6edb9;
    bytes32 internal constant NORMAL_HASH = 0x805b27b309dc7278abbf4ea14f2abcf592a1b10005ceba9019e67af4d05b2f95;
    bytes32 internal constant EVIDENCE_HASH = bytes32(uint256(0x123));

    MeterProfileOrigin internal origin;
    ReactiveMeterGuard internal reactive;
    SettlementEscrow internal escrow;

    function setUp() public {
        MockSystemE2E mock = new MockSystemE2E();
        vm.etch(SYSTEM, address(mock).code);
        origin = new MeterProfileOrigin();
        origin.setMeterAuthorization(METER, true);
        reactive = new ReactiveMeterGuard(ORIGIN_CHAIN, address(origin), ORIGIN_CHAIN);
        escrow = new SettlementEscrow(CALLBACK_PROXY, address(reactive), REVIEWER);
        reactive.setSettlementEscrow(address(escrow));
        reactive.activate();
        vm.deal(address(this), 2 ether);
    }

    function _flaggedFeatures() internal pure returns (int256[10] memory f) {
        f = [
            int256(-1788879),
            int256(0),
            int256(310599),
            int256(1592873),
            int256(14196),
            int256(989319),
            int256(193748),
            int256(-176319),
            int256(-1795677),
            int256(-1811959)
        ];
    }

    function _normalFeatures() internal pure returns (int256[10] memory f) {
        f = [
            int256(497073),
            int256(0),
            int256(317831),
            int256(1604123),
            int256(9910),
            int256(996157),
            int256(200131),
            int256(-274570),
            int256(489506),
            int256(508166)
        ];
    }

    function _submitAndReact(uint64 sequence, bytes32 profileHash, int256[10] memory features) internal {
        vm.recordLogs();
        vm.prank(METER);
        origin.submitProfile(sequence, profileHash, features);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        Vm.Log memory sourceLog = logs[0];
        assertEq(sourceLog.emitter, address(origin));
        assertEq(sourceLog.topics.length, 4);

        vm.prank(SYSTEM);
        reactive.react(_record(sourceLog));
    }

    function _record(Vm.Log memory sourceLog) private view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(origin),
            topic0: uint256(sourceLog.topics[0]),
            topic1: uint256(sourceLog.topics[1]),
            topic2: uint256(sourceLog.topics[2]),
            topic3: uint256(sourceLog.topics[3]),
            data: sourceLog.data,
            blockNumber: block.number,
            opCode: sourceLog.topics.length,
            blockHash: uint256(blockhash(block.number - 1)),
            txHash: 0,
            logIndex: 0
        });
    }

    function testSignedTheft1ProfileTriggersHumanReviewAndRelease() public {
        escrow.deposit{value: 1 ether}(METER, 1, FLAGGED_HASH);
        _submitAndReact(1, FLAGGED_HASH, _flaggedFeatures());

        MockSystemE2E system = MockSystemE2E(SYSTEM);
        assertEq(system.callbackCount(), 1);
        assertEq(system.callbackChainId(), ORIGIN_CHAIN);
        assertEq(system.callbackRecipient(), address(escrow));
        assertEq(system.callbackGasLimit(), 350000);

        bytes memory expectedPayload = abi.encodeWithSignature(
            "onSettlementDecision(address,address,uint64,bytes32,bool,int256,uint32)",
            address(0),
            METER,
            uint64(1),
            FLAGGED_HASH,
            true,
            int256(26727442),
            uint32(1)
        );
        assertEq(system.callbackPayload(), expectedPayload);

        // Simulate callback delivery through the Base Sepolia proxy with injected Reactive sender.
        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(address(reactive), METER, 1, FLAGGED_HASH, true, 26727442, 1);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(FLAGGED_HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.HOLD_FOR_REVIEW));

        vm.prank(REVIEWER);
        escrow.approveHeldSettlement(escrow.settlementId(METER, 1, FLAGGED_HASH), EVIDENCE_HASH);
        vm.prank(REVIEWER);
        escrow.release(escrow.settlementId(METER, 1, FLAGGED_HASH));
        assertEq(METER.balance, 1 ether);
    }

    function testNormalDatasetProfileBecomesReleaseReadyButStillNeedsHumanRelease() public {
        escrow.deposit{value: 0.5 ether}(METER, 1, NORMAL_HASH);
        _submitAndReact(1, NORMAL_HASH, _normalFeatures());

        MockSystemE2E system = MockSystemE2E(SYSTEM);
        assertEq(system.callbackCount(), 1);
        bytes memory expectedPayload = abi.encodeWithSignature(
            "onSettlementDecision(address,address,uint64,bytes32,bool,int256,uint32)",
            address(0),
            METER,
            uint64(1),
            NORMAL_HASH,
            false,
            int256(-3583974),
            uint32(1)
        );
        assertEq(system.callbackPayload(), expectedPayload);

        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(address(reactive), METER, 1, NORMAL_HASH, false, -3583974, 1);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(NORMAL_HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.RELEASE_READY));
        assertEq(METER.balance, 0);

        vm.prank(REVIEWER);
        escrow.release(escrow.settlementId(METER, 1, NORMAL_HASH));
        assertEq(METER.balance, 0.5 ether);
    }

    function testUnregisteredMeterCannotSubmit() public {
        vm.prank(address(0x4444));
        vm.expectRevert();
        origin.submitProfile(1, FLAGGED_HASH, _flaggedFeatures());
    }

    function testMeterCannotReplaySequence() public {
        vm.prank(METER);
        origin.submitProfile(1, FLAGGED_HASH, _flaggedFeatures());
        vm.prank(METER);
        vm.expectRevert();
        origin.submitProfile(1, bytes32(uint256(0xdef)), _flaggedFeatures());
    }

    function testOperatorCanRecoverUndeliveredProfileAfterLaterDecision() public {
        bytes32 flaggedId = escrow.settlementId(METER, 1, FLAGGED_HASH);
        escrow.deposit{value: 1 ether}(METER, 1, FLAGGED_HASH);
        _submitAndReact(1, FLAGGED_HASH, _flaggedFeatures());
        _submitAndReact(2, NORMAL_HASH, _normalFeatures());
        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(address(reactive), METER, 2, NORMAL_HASH, false, -3583974, 1);

        Vm.Log memory replay = _requestReplay();
        vm.prank(SYSTEM);
        reactive.react(_record(replay));
        vm.prank(SYSTEM);
        reactive.react(_record(replay));
        assertEq(MockSystemE2E(SYSTEM).callbackCount(), 3);

        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(address(reactive), METER, 1, FLAGGED_HASH, true, 26727442, 1);
        (,,, SettlementEscrow.Status status,,,,) = escrow.settlements(flaggedId);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.HOLD_FOR_REVIEW));
    }

    function testRecoveryRequiresOriginalFeaturesAndOperator() public {
        _submitAndReact(1, FLAGGED_HASH, _flaggedFeatures());
        vm.expectRevert("PROFILE_MISMATCH");
        origin.retryProfile(METER, 1, FLAGGED_HASH, _normalFeatures());
        vm.prank(METER);
        vm.expectRevert("NOT_OWNER");
        origin.retryProfile(METER, 1, FLAGGED_HASH, _flaggedFeatures());
    }

    function _requestReplay() private returns (Vm.Log memory) {
        vm.recordLogs();
        origin.retryProfile(METER, 1, FLAGGED_HASH, _flaggedFeatures());
        return vm.getRecordedLogs()[0];
    }

    function _settlement(bytes32 key)
        internal
        view
        returns (
            address meter,
            uint64 sequence,
            uint256 amount,
            SettlementEscrow.Status status,
            int256 logitQ,
            uint32 modelVersion,
            bytes32 evidenceHash,
            bool decisionRecorded
        )
    {
        return escrow.settlements(escrow.settlementId(METER, 1, key));
    }
}
