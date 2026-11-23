// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {SettlementEscrow} from "../src/SettlementEscrow.sol";

contract SettlementEscrowTest is Test {
    address internal constant CALLBACK_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;
    address internal constant REACTIVE = address(0x8888);
    address internal constant REVIEWER = address(0x9999);
    address internal constant METER = address(0x3333);
    bytes32 internal constant HASH = bytes32(uint256(0xabc));
    bytes32 internal constant HASH_2 = bytes32(uint256(0xdef));
    bytes32 internal constant EVIDENCE = bytes32(uint256(0x123));
    SettlementEscrow internal escrow;

    function setUp() public {
        escrow = new SettlementEscrow(CALLBACK_PROXY, REACTIVE, REVIEWER);
        vm.deal(address(this), 10 ether);
    }

    function _callback(bytes32 profileHash, uint64 sequence, bool flagged) internal {
        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(REACTIVE, METER, sequence, profileHash, flagged, 123456, 1);
    }

    function testFlaggedSettlementRequiresHumanEvidenceBeforeRelease() public {
        escrow.deposit{value: 1 ether}(METER, 1, HASH);
        _callback(HASH, 1, true);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.HOLD_FOR_REVIEW));

        vm.expectRevert();
        escrow.release(_id(HASH));

        vm.prank(REVIEWER);
        escrow.approveHeldSettlement(_id(HASH), EVIDENCE);
        bytes32 evidenceHash;
        (,,, status,,, evidenceHash,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.REVIEW_APPROVED));
        assertEq(evidenceHash, EVIDENCE);

        uint256 beforeBalance = METER.balance;
        vm.prank(REVIEWER);
        escrow.release(_id(HASH));
        (,, uint256 remaining, SettlementEscrow.Status finalStatus,,,,) = _settlement(HASH);
        assertEq(remaining, 0);
        assertEq(uint256(finalStatus), uint256(SettlementEscrow.Status.RELEASED));
        assertEq(METER.balance - beforeBalance, 1 ether);
    }

    function testNormalSettlementStillNeedsManualRelease() public {
        escrow.deposit{value: 0.5 ether}(METER, 1, HASH);
        _callback(HASH, 1, false);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.RELEASE_READY));
        assertEq(METER.balance, 0);
        vm.prank(REVIEWER);
        escrow.release(_id(HASH));
        assertEq(METER.balance, 0.5 ether);
    }

    function testDirectEOACannotForgeCallbackEvenWithCorrectReactiveAddress() public {
        vm.expectRevert();
        escrow.onSettlementDecision(REACTIVE, METER, 1, HASH, false, 0, 1);
    }

    function testLegitimateProxyRejectsUnapprovedReactiveSender() public {
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert();
        escrow.onSettlementDecision(address(0xdead), METER, 1, HASH, false, 0, 1);
    }

    function testDuplicateDecisionCannotDowngradeHold() public {
        _callback(HASH, 1, true);
        _callback(HASH, 1, false);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.HOLD_FOR_REVIEW));
    }

    function testIndependentSequenceCanArriveOutOfOrder() public {
        _callback(HASH, 2, false);
        _callback(HASH_2, 1, true);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(HASH_2);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.HOLD_FOR_REVIEW));
    }

    function testProxyFeesCannotSpendPrincipal() public {
        escrow.deposit{value: 1 ether}(METER, 1, HASH);
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert("INSUFFICIENT_FEE_SURPLUS");
        escrow.pay(1);
        vm.deal(address(escrow), 1 ether + 2);
        vm.prank(CALLBACK_PROXY);
        escrow.pay(2);
        assertEq(escrow.totalPrincipal(), 1 ether);
        assertEq(address(escrow).balance, 1 ether);
        _callback(HASH, 1, false);
        escrow.release(_id(HASH));
        assertEq(escrow.totalPrincipal(), 0);
        assertEq(METER.balance, 1 ether);
    }

    function testDecisionCannotTakeFundingFromAnotherMeter() public {
        escrow.deposit{value: 1 ether}(METER, 1, HASH);
        address other = address(0x1234);
        vm.prank(CALLBACK_PROXY);
        escrow.onSettlementDecision(REACTIVE, other, 1, HASH, false, 0, 1);
        bytes32 otherId = escrow.settlementId(other, 1, HASH);
        vm.expectRevert("NO_FUNDS");
        escrow.release(otherId);
        assertEq(escrow.totalPrincipal(), 1 ether);
        _callback(HASH, 1, false);
        escrow.release(_id(HASH));
        assertEq(METER.balance, 1 ether);
    }

    function testUndeliveredRefundAndLateCallback() public {
        escrow.deposit{value: 1 ether}(METER, 1, HASH);
        vm.expectRevert("REFUND_NOT_READY");
        escrow.refundUndelivered(_id(HASH));
        vm.warp(block.timestamp + escrow.DELIVERY_TIMEOUT());
        uint256 before = address(this).balance;
        escrow.refundUndelivered(_id(HASH));
        assertEq(address(this).balance - before, 1 ether);
        _callback(HASH, 1, false);
        (,,, SettlementEscrow.Status status,,,,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.REFUNDED));
        assertEq(escrow.totalPrincipal(), 0);
    }

    function testReviewerCanRejectHeldCaseWithEvidence() public {
        escrow.deposit{value: 1 ether}(METER, 1, HASH);
        _callback(HASH, 1, true);
        vm.prank(REVIEWER);
        escrow.rejectHeldSettlement(_id(HASH), EVIDENCE);
        (,,, SettlementEscrow.Status status,,, bytes32 evidence,) = _settlement(HASH);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.REFUNDED));
        assertEq(evidence, EVIDENCE);
        assertEq(escrow.totalPrincipal(), 0);
    }

    receive() external payable {}

    function _id(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encode(METER, uint64(1), hash));
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
        return escrow.settlements(_id(key));
    }
}
