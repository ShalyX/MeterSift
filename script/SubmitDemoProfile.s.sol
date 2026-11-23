// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {MeterProfileOrigin} from "../src/MeterProfileOrigin.sol";

contract SubmitDemoProfile is Script {
    function run() external {
        address originAddress = vm.envAddress("ORIGIN_CONTRACT_ADDRESS");
        string memory fixture = vm.envOr("PROFILE_FIXTURE", string("examples/flagged_profile_payload.json"));
        uint256 rawSequence = vm.envOr("PROFILE_SEQUENCE", uint256(1));
        require(rawSequence > 0 && rawSequence <= type(uint64).max, "INVALID_SEQUENCE");

        string memory json = vm.readFile(fixture);
        require(vm.parseJsonAddress(json, ".meter") == tx.origin, "FIXTURE_SIGNER_MISMATCH");
        require(vm.parseJsonUint(json, ".sequence") == rawSequence, "FIXTURE_SEQUENCE_MISMATCH");
        bytes32 profileHash = vm.parseJsonBytes32(json, ".profileHash");
        int256[] memory parsedFeatures = vm.parseJsonIntArray(json, ".features");
        require(parsedFeatures.length == 10, "EXPECTED_TEN_FEATURES");

        int256[10] memory features;
        for (uint256 i; i < 10; ++i) {
            features[i] = parsedFeatures[i];
        }

        // The explicit bound check above guarantees this cast cannot truncate.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 sequence = uint64(rawSequence);

        vm.startBroadcast();
        MeterProfileOrigin(originAddress).submitProfile(sequence, profileHash, features);
        vm.stopBroadcast();

        console2.log("PROFILE_SUBMITTED_TO", originAddress);
        console2.log("SEQUENCE", uint256(sequence));
        console2.log("PROFILE_HASH");
        console2.logBytes32(profileHash);
    }
}
