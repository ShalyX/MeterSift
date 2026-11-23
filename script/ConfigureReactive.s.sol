// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {ReactiveMeterGuard} from "../src/ReactiveMeterGuard.sol";

contract ConfigureReactive is Script {
    function run() external {
        address reactiveAddress = vm.envAddress("REACTIVE_CONTRACT_ADDRESS");
        address escrowAddress = vm.envAddress("SETTLEMENT_ESCROW_ADDRESS");
        ReactiveMeterGuard reactive = ReactiveMeterGuard(payable(reactiveAddress));

        vm.startBroadcast();
        reactive.setSettlementEscrow(escrowAddress);
        reactive.activate();
        vm.stopBroadcast();

        console2.log("REACTIVE_CONTRACT", reactiveAddress);
        console2.log("SETTLEMENT_ESCROW", escrowAddress);
        console2.log("SUBSCRIPTION_ACTIVE", reactive.active());
    }
}
