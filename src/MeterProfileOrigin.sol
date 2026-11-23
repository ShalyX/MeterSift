// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @notice Base-chain intake. The submitting meter EOA signs the transaction and feature vector.
contract MeterProfileOrigin {
    address public immutable owner;
    mapping(address => bool) public meterAuthorized;
    mapping(address => uint64) public lastSequence;
    mapping(address => mapping(uint64 => bytes32)) public submissionDigest;
    mapping(address => mapping(uint64 => uint64)) public replayAttempt;

    event MeterAuthorizationChanged(address indexed meter, bool authorized);
    event MeterProfileSubmitted(
        address indexed meter, uint64 indexed sequence, bytes32 indexed profileHash, int256[10] features
    );
    event MeterProfileReplayRequested(
        address indexed meter, uint64 indexed sequence, bytes32 indexed profileHash, int256[10] features, uint64 attempt
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setMeterAuthorization(address meter, bool authorized) external onlyOwner {
        require(meter != address(0), "ZERO_METER");
        meterAuthorized[meter] = authorized;
        emit MeterAuthorizationChanged(meter, authorized);
    }

    /// @dev Feature values use 1e6 fixed-point scale. Raw readings stay off-chain;
    ///      profileHash commits to the source profile while this transaction signs the features.
    function submitProfile(uint64 sequence, bytes32 profileHash, int256[10] calldata features) external {
        require(meterAuthorized[msg.sender], "METER_NOT_AUTHORIZED");
        require(sequence == lastSequence[msg.sender] + 1, "BAD_SEQUENCE");
        require(profileHash != bytes32(0), "ZERO_PROFILE_HASH");

        for (uint256 i; i < 10; ++i) {
            require(features[i] >= -100_000_000 && features[i] <= 100_000_000, "FEATURE_OUT_OF_RANGE");
        }

        lastSequence[msg.sender] = sequence;
        submissionDigest[msg.sender][sequence] = keccak256(abi.encode(profileHash, features));
        emit MeterProfileSubmitted(msg.sender, sequence, profileHash, features);
    }

    /// @notice Re-emit an existing meter submission for recovery even if the first event never reached Lasna.
    function retryProfile(address meter, uint64 sequence, bytes32 profileHash, int256[10] calldata features)
        external
        onlyOwner
    {
        bytes32 digest = submissionDigest[meter][sequence];
        require(digest != bytes32(0) && digest == keccak256(abi.encode(profileHash, features)), "PROFILE_MISMATCH");
        uint64 attempt = ++replayAttempt[meter][sequence];
        emit MeterProfileReplayRequested(meter, sequence, profileHash, features, attempt);
    }
}
