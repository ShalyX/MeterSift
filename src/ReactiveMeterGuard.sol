// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {MeterSettlementModel} from "./MeterSettlementModel.sol";

/// @notice Reactive Omni AI screening contract. It never seizes funds or penalizes a meter.
contract ReactiveMeterGuard is AbstractReactive, MeterSettlementModel {
    uint32 public constant MODEL_VERSION = 1;
    uint64 public constant CALLBACK_GAS_LIMIT = 350_000;
    uint256 public constant PROFILE_TOPIC0 =
        uint256(keccak256("MeterProfileSubmitted(address,uint64,bytes32,int256[10])"));
    uint256 public constant REPLAY_TOPIC0 =
        uint256(keccak256("MeterProfileReplayRequested(address,uint64,bytes32,int256[10],uint64)"));

    address public immutable owner;
    uint256 public immutable originChainId;
    address public immutable originContract;
    uint256 public immutable destinationChainId;
    address public settlementEscrow;
    bool public active;

    mapping(bytes32 => bool) public processed;
    mapping(bytes32 => uint64) public lastReplayAttempt;
    mapping(address => uint64) public lastSequence;

    event SettlementEscrowConfigured(address indexed escrow);
    event SubscriptionActivated(uint256 indexed originChainId, address indexed originContract);
    event SubscriptionDeactivated(uint256 indexed originChainId, address indexed originContract);
    event ReviewRouted(bytes32 indexed settlementId, uint8 reason);
    event DecisionEvaluated(
        address indexed meter,
        uint64 indexed sequence,
        bytes32 indexed profileHash,
        bool flagged,
        int256 logitQ,
        uint32 modelVersion
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(uint256 originChainId_, address originContract_, uint256 destinationChainId_) payable {
        require(originContract_ != address(0), "ZERO_ORIGIN");
        owner = msg.sender;
        originChainId = originChainId_;
        originContract = originContract_;
        destinationChainId = destinationChainId_;
    }

    /// @notice Configure after deploying the destination escrow with this contract's address.
    function setSettlementEscrow(address escrow_) external onlyOwner {
        require(!active, "ALREADY_ACTIVE");
        require(escrow_ != address(0), "ZERO_ESCROW");
        settlementEscrow = escrow_;
        emit SettlementEscrowConfigured(escrow_);
    }

    /// @notice Subscribe only after the callback recipient is configured.
    function activate() external onlyOwner {
        require(!active, "ALREADY_ACTIVE");
        require(settlementEscrow != address(0), "ESCROW_NOT_SET");
        SYSTEM.subscribe(
            originChainId, originContract, PROFILE_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        SYSTEM.subscribe(
            originChainId, originContract, REPLAY_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        active = true;
        emit SubscriptionActivated(originChainId, originContract);
    }

    /// @notice Owner-controlled emergency pause; removes the event subscription.
    function deactivate() external onlyOwner {
        require(active, "NOT_ACTIVE");
        SYSTEM.unsubscribe(
            originChainId, originContract, PROFILE_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        SYSTEM.unsubscribe(
            originChainId, originContract, REPLAY_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        active = false;
        emit SubscriptionDeactivated(originChainId, originContract);
    }

    /// @inheritdoc IReactive
    function react(LogRecord memory log_) external override onlySystem {
        if (!active || settlementEscrow == address(0)) return;
        if (
            log_.chainId != originChainId || log_.contractAddress != originContract || log_.opCode != 4
                || (log_.topic0 != PROFILE_TOPIC0 && log_.topic0 != REPLAY_TOPIC0)
        ) return;

        address meter = address(uint160(log_.topic1));
        uint64 sequence = uint64(log_.topic2);
        bytes32 profileHash = bytes32(log_.topic3);
        bytes32 eventId = keccak256(abi.encode(meter, sequence, profileHash));

        if (meter == address(0) || sequence == 0 || profileHash == bytes32(0)) return;
        int256[10] memory features;
        if (log_.topic0 == REPLAY_TOPIC0) {
            uint64 attempt;
            (features, attempt) = abi.decode(log_.data, (int256[10], uint64));
            if (attempt <= lastReplayAttempt[eventId]) return;
            lastReplayAttempt[eventId] = attempt;
        } else {
            if (processed[eventId]) return;
            features = abi.decode(log_.data, (int256[10]));
        }
        (int256 logitQ, uint8 reason) = screen(features);
        bool flagged = reason != 0;

        processed[eventId] = true;
        if (sequence > lastSequence[meter]) lastSequence[meter] = sequence;

        emit DecisionEvaluated(meter, sequence, profileHash, flagged, logitQ, MODEL_VERSION);
        if (flagged) emit ReviewRouted(eventId, reason);

        // Reactive replaces the first address argument with this contract's address.
        bytes memory payload = abi.encodeWithSignature(
            "onSettlementDecision(address,address,uint64,bytes32,bool,int256,uint32)",
            address(0),
            meter,
            sequence,
            profileHash,
            flagged,
            logitQ,
            MODEL_VERSION
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId, recipient: settlementEscrow, gasLimit: CALLBACK_GAS_LIMIT, payload: payload
            })
        );
    }
}
