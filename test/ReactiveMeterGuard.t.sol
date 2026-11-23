// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {ReactiveMeterGuard} from "../src/ReactiveMeterGuard.sol";

contract MockReactiveSystem {
    uint256 public subscribeCount;
    uint256 public unsubscribeCount;
    uint256 public callbackCount;
    uint256 public lastChainId;
    address public lastContract;
    uint256 public lastTopic0;
    address public lastRecipient;
    uint64 public lastGasLimit;
    bytes public lastPayload;

    function subscribe(uint256 chainId_, address contract_, uint256 topic0_, uint256, uint256, uint256) external {
        subscribeCount++;
        lastChainId = chainId_;
        lastContract = contract_;
        lastTopic0 = topic0_;
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        unsubscribeCount++;
    }

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config_) external {
        callbackCount++;
        lastChainId = config_.chainId;
        lastRecipient = config_.recipient;
        lastGasLimit = config_.gasLimit;
        lastPayload = config_.payload;
    }
}

contract ReactiveMeterGuardTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    uint256 internal constant ORIGIN_CHAIN = 84532;
    uint256 internal constant DESTINATION_CHAIN = 84532;
    address internal constant ORIGIN = address(0x1111);
    address internal constant ESCROW = address(0x2222);
    address internal constant METER = address(0x3333);
    bytes32 internal constant PROFILE_HASH = bytes32(uint256(0xabc));
    uint256 internal constant TOPIC0 = uint256(keccak256("MeterProfileSubmitted(address,uint64,bytes32,int256[10])"));

    ReactiveMeterGuard internal guard;

    function setUp() public {
        MockReactiveSystem mock = new MockReactiveSystem();
        vm.etch(SYSTEM, address(mock).code);
        guard = new ReactiveMeterGuard(ORIGIN_CHAIN, ORIGIN, DESTINATION_CHAIN);
        guard.setSettlementEscrow(ESCROW);
        guard.activate();
    }

    function _features() internal pure returns (int256[10] memory f) {
        f = [
            int256(120000),
            int256(40000),
            int256(550000),
            int256(2100000),
            int256(150000),
            int256(820000),
            int256(180000),
            int256(240000),
            int256(80000),
            int256(-40000)
        ];
    }

    function _log(uint64 sequence) internal pure returns (IReactive.LogRecord memory log_) {
        log_ = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: ORIGIN,
            topic0: TOPIC0,
            topic1: uint256(uint160(METER)),
            topic2: uint256(sequence),
            topic3: uint256(PROFILE_HASH),
            data: abi.encode(_features()),
            blockNumber: 123,
            opCode: 4,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function testSubscribesToCorrectOriginEvent() public view {
        MockReactiveSystem system = MockReactiveSystem(SYSTEM);
        assertEq(system.subscribeCount(), 2);
        assertEq(system.lastChainId(), ORIGIN_CHAIN);
        assertEq(system.lastContract(), ORIGIN);
        assertEq(system.lastTopic0(), guard.REPLAY_TOPIC0());
    }

    function testReactiveModelRequestsAuthenticatedCallback() public {
        vm.prank(SYSTEM);
        guard.react(_log(1));

        bytes memory expected = abi.encodeWithSignature(
            "onSettlementDecision(address,address,uint64,bytes32,bool,int256,uint32)",
            address(0),
            METER,
            uint64(1),
            PROFILE_HASH,
            true,
            int256(2835708),
            uint32(1)
        );
        MockReactiveSystem system = MockReactiveSystem(SYSTEM);
        assertEq(system.callbackCount(), 1);
        assertEq(system.lastChainId(), DESTINATION_CHAIN);
        assertEq(system.lastRecipient(), ESCROW);
        assertEq(system.lastGasLimit(), 350000);
        assertEq(system.lastPayload(), expected);
        assertEq(guard.lastSequence(METER), 1);
    }

    function testDuplicateProfileIsIdempotent() public {
        IReactive.LogRecord memory log_ = _log(1);
        vm.prank(SYSTEM);
        guard.react(log_);
        vm.prank(SYSTEM);
        guard.react(log_);
        assertEq(MockReactiveSystem(SYSTEM).callbackCount(), 1);
    }

    function testOlderIndependentSequenceIsProcessed() public {
        vm.prank(SYSTEM);
        guard.react(_log(2));
        vm.prank(SYSTEM);
        guard.react(_log(1));
        assertEq(MockReactiveSystem(SYSTEM).callbackCount(), 2);
        assertEq(guard.lastSequence(METER), 2);
    }

    function testWrongOriginFallsThroughWithoutRevert() public {
        IReactive.LogRecord memory log_ = _log(1);
        log_.chainId = ORIGIN_CHAIN + 1;
        vm.prank(SYSTEM);
        guard.react(log_);
        assertEq(MockReactiveSystem(SYSTEM).callbackCount(), 0);
    }

    function testUnauthorizedCallerRejected() public {
        vm.expectRevert();
        guard.react(_log(1));
    }

    function testOwnerCanDeactivateAndResumeSubscription() public {
        guard.deactivate();
        assertFalse(guard.active());
        assertEq(MockReactiveSystem(SYSTEM).unsubscribeCount(), 2);

        vm.prank(SYSTEM);
        guard.react(_log(1));
        assertEq(MockReactiveSystem(SYSTEM).callbackCount(), 0);

        guard.activate();
        assertTrue(guard.active());
        assertEq(MockReactiveSystem(SYSTEM).subscribeCount(), 4);
    }

    function testNonOwnerCannotDeactivateSubscription() public {
        vm.prank(address(0xdead));
        vm.expectRevert();
        guard.deactivate();
        assertTrue(guard.active());
    }

    function testFullReactivePathGas() public {
        MockReactiveSystemLight light = new MockReactiveSystemLight();
        vm.etch(SYSTEM, address(light).code);
        uint256 beforeGas = gasleft();
        vm.prank(SYSTEM);
        guard.react(_log(1));
        uint256 used = beforeGas - gasleft();
        emit log_named_uint("react + model + event-only callback request gas", used);
        assertLt(used, 180000);
    }
}

contract MockReactiveSystemLight {
    event CallbackRequested(uint256 indexed chainId, address indexed recipient, uint64 gasLimit, bytes payload);
    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {}

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory c) external {
        emit CallbackRequested(c.chainId, c.recipient, c.gasLimit, c.payload);
    }
}
