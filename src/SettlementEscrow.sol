// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IPayer} from "@reactive/src/interfaces/IPayer.sol";

/// @notice Destination-chain settlement state machine with authenticated Reactive callbacks.
contract SettlementEscrow is IPayer {
    uint256 public constant DELIVERY_TIMEOUT = 1 days;

    enum Status {
        NONE,
        PENDING,
        RELEASE_READY,
        HOLD_FOR_REVIEW,
        REVIEW_APPROVED,
        RELEASED,
        REFUNDED
    }

    struct Settlement {
        address meter;
        uint64 sequence;
        uint256 amount;
        Status status;
        int256 logitQ;
        uint32 modelVersion;
        bytes32 evidenceHash;
        bool decisionRecorded;
    }

    address public immutable owner;
    address public immutable _SERVICE_PROVIDER;
    address public immutable _CALLBACK_SENDER;
    address public reviewer;
    uint256 public totalPrincipal;

    mapping(bytes32 => Settlement) public settlements;
    mapping(bytes32 => uint256) public refundAfter;

    event Deposited(
        bytes32 indexed settlementId,
        address indexed meter,
        bytes32 indexed profileHash,
        uint64 sequence,
        uint256 amount
    );
    event DecisionRecorded(
        bytes32 indexed profileHash,
        address indexed meter,
        uint64 sequence,
        Status status,
        int256 logitQ,
        uint32 modelVersion
    );
    event HumanReviewApproved(bytes32 indexed settlementId, address indexed reviewer, bytes32 evidenceHash);
    event SettlementReleased(bytes32 indexed settlementId, address indexed meter, uint256 amount);
    event SettlementRefunded(bytes32 indexed settlementId, uint256 amount, bytes32 evidenceHash);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyReviewer() {
        require(msg.sender == owner || msg.sender == reviewer, "NOT_REVIEWER");
        _;
    }

    constructor(address callbackProxy_, address reactive_, address reviewer_) {
        require(callbackProxy_ != address(0), "ZERO_CALLBACK_PROXY");
        require(reactive_ != address(0), "ZERO_REACTIVE");
        owner = msg.sender;
        _SERVICE_PROVIDER = callbackProxy_;
        _CALLBACK_SENDER = reactive_;
        reviewer = reviewer_ == address(0) ? msg.sender : reviewer_;
    }

    function setReviewer(address reviewer_) external onlyOwner {
        require(reviewer_ != address(0), "ZERO_REVIEWER");
        reviewer = reviewer_;
    }

    receive() external payable {}

    /// @notice The callback proxy may collect fees from surplus only.
    function pay(uint256 amount) external {
        require(msg.sender == _SERVICE_PROVIDER, "NOT_PROXY");
        require(amount <= address(this).balance - totalPrincipal, "INSUFFICIENT_FEE_SURPLUS");
        if (amount > 0) _transfer(msg.sender, amount);
    }

    function settlementId(address meter, uint64 sequence, bytes32 profileHash) public pure returns (bytes32) {
        return keccak256(abi.encode(meter, sequence, profileHash));
    }

    function deposit(address meter, uint64 sequence, bytes32 profileHash) external payable onlyOwner {
        require(meter != address(0) && sequence != 0 && profileHash != bytes32(0), "INVALID_PROFILE");
        require(msg.value > 0, "ZERO_DEPOSIT");
        bytes32 id = settlementId(meter, sequence, profileHash);
        Settlement storage s = settlements[id];
        require(s.status != Status.RELEASED && s.status != Status.REFUNDED, "SETTLEMENT_CLOSED");
        if (s.status == Status.NONE) {
            s.meter = meter;
            s.sequence = sequence;
            s.status = Status.PENDING;
            refundAfter[id] = block.timestamp + DELIVERY_TIMEOUT;
        }
        s.amount += msg.value;
        totalPrincipal += msg.value;
        emit Deposited(id, meter, profileHash, sequence, msg.value);
    }

    /// @notice Both guards are required: proxy authentication and Reactive-contract authentication.
    function onSettlementDecision(
        address reactiveSender,
        address meter,
        uint64 sequence,
        bytes32 profileHash,
        bool flagged,
        int256 logitQ,
        uint32 modelVersion
    ) external {
        require(msg.sender == _SERVICE_PROVIDER, "NOT_PROXY");
        require(reactiveSender == _CALLBACK_SENDER, "NOT_REACTIVE");
        require(meter != address(0) && sequence != 0 && profileHash != bytes32(0), "INVALID_PROFILE");

        Settlement storage s = settlements[settlementId(meter, sequence, profileHash)];
        if (s.decisionRecorded || s.status == Status.REFUNDED) return;

        s.meter = meter;
        s.sequence = sequence;
        s.logitQ = logitQ;
        s.modelVersion = modelVersion;
        s.decisionRecorded = true;
        s.status = flagged ? Status.HOLD_FOR_REVIEW : Status.RELEASE_READY;

        emit DecisionRecorded(profileHash, meter, sequence, s.status, logitQ, modelVersion);
    }

    /// @notice A held settlement requires an explicit human decision and evidence commitment.
    function approveHeldSettlement(bytes32 id, bytes32 evidenceHash) external onlyReviewer {
        Settlement storage s = settlements[id];
        require(s.status == Status.HOLD_FOR_REVIEW, "NOT_HELD");
        require(evidenceHash != bytes32(0), "MISSING_EVIDENCE");
        s.evidenceHash = evidenceHash;
        s.status = Status.REVIEW_APPROVED;
        emit HumanReviewApproved(id, msg.sender, evidenceHash);
    }

    function rejectHeldSettlement(bytes32 id, bytes32 evidenceHash) external onlyReviewer {
        Settlement storage s = settlements[id];
        require(s.status == Status.HOLD_FOR_REVIEW, "NOT_HELD");
        require(evidenceHash != bytes32(0), "MISSING_EVIDENCE");
        s.evidenceHash = evidenceHash;
        _refund(id, s);
    }

    function refundUndelivered(bytes32 id) external onlyOwner {
        Settlement storage s = settlements[id];
        require(s.status == Status.PENDING && block.timestamp >= refundAfter[id], "REFUND_NOT_READY");
        _refund(id, s);
    }

    /// @notice An operator explicitly releases a ready or human-approved settlement.
    function release(bytes32 id) external onlyReviewer {
        Settlement storage s = settlements[id];
        require(s.status == Status.RELEASE_READY || s.status == Status.REVIEW_APPROVED, "NOT_RELEASEABLE");
        require(s.amount > 0, "NO_FUNDS");
        address meter = s.meter;
        uint256 amount = s.amount;
        s.amount = 0;
        s.status = Status.RELEASED;
        totalPrincipal -= amount;

        _transfer(meter, amount);
        emit SettlementReleased(id, meter, amount);
    }

    function _refund(bytes32 id, Settlement storage s) private {
        uint256 amount = s.amount;
        s.amount = 0;
        s.status = Status.REFUNDED;
        totalPrincipal -= amount;
        if (amount > 0) _transfer(owner, amount);
        emit SettlementRefunded(id, amount, s.evidenceHash);
    }

    function _transfer(address recipient, uint256 amount) private {
        (bool ok,) = payable(recipient).call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}
