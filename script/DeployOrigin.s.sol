// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {MeterProfileOrigin} from "../src/MeterProfileOrigin.sol";

contract DeployOrigin is Script {
    function run() external returns (MeterProfileOrigin origin) {
        address meter = vm.envOr("METER_ADDRESS", tx.origin);

        vm.startBroadcast();
        origin = new MeterProfileOrigin();
        origin.setMeterAuthorization(meter, true);
        vm.stopBroadcast();

        console2.log("ORIGIN_CONTRACT", address(origin));
        console2.log("AUTHORIZED_METER", meter);
    }
}
