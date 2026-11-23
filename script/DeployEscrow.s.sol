// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {SettlementEscrow} from "../src/SettlementEscrow.sol";

contract DeployEscrow is Script {
    address internal constant BASE_SEPOLIA_CALLBACK_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;

    function run() external returns (SettlementEscrow escrow) {
        address callbackProxy = vm.envOr("CALLBACK_PROXY_ADDRESS", BASE_SEPOLIA_CALLBACK_PROXY);
        address reactive = vm.envAddress("REACTIVE_CONTRACT_ADDRESS");
        address reviewer = vm.envOr("REVIEWER_ADDRESS", tx.origin);

        vm.startBroadcast();
        escrow = new SettlementEscrow(callbackProxy, reactive, reviewer);
        vm.stopBroadcast();

        console2.log("SETTLEMENT_ESCROW", address(escrow));
        console2.log("CALLBACK_PROXY", callbackProxy);
        console2.log("AUTHORIZED_REACTIVE_SENDER", reactive);
        console2.log("REVIEWER", reviewer);
    }
}
