// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {ReactiveMeterGuard} from "../src/ReactiveMeterGuard.sol";

contract DeployReactive is Script {
    function run() external returns (ReactiveMeterGuard reactive) {
        uint256 originChainId = vm.envOr("ORIGIN_CHAIN_ID", uint256(84532));
        uint256 destinationChainId = vm.envOr("DESTINATION_CHAIN_ID", uint256(84532));
        address origin = vm.envAddress("ORIGIN_CONTRACT_ADDRESS");

        vm.startBroadcast();
        reactive = new ReactiveMeterGuard(originChainId, origin, destinationChainId);
        vm.stopBroadcast();

        console2.log("REACTIVE_CONTRACT", address(reactive));
        console2.log("ORIGIN_CONTRACT", origin);
        console2.log("ORIGIN_CHAIN_ID", originChainId);
        console2.log("DESTINATION_CHAIN_ID", destinationChainId);
    }
}
