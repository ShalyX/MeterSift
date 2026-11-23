// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
import {Test} from "forge-std/Test.sol";
import {MeterSettlementModel} from "../src/MeterSettlementModel.sol";

contract MeterSettlementModelTest is Test {
    MeterSettlementModel model;

    function setUp() public {
        model = new MeterSettlementModel();
    }

    function testFixedPointParityVector() public view {
        int256[10] memory raw = [
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
        (int256 actual, bool flagged) = model.infer(raw);
        assertEq(actual, 2835708);
        assertEq(flagged, true);
    }

    function testInferenceGas() public {
        int256[10] memory raw = [
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
        uint256 beforeGas = gasleft();
        model.infer(raw);
        uint256 used = beforeGas - gasleft();
        emit log_named_uint("model inference gas", used);
    }

    function testOrdinaryScoreNearCutoffRoutesToReview() public view {
        int256[10] memory raw = [
            int256(-74416),
            int256(0),
            int256(316022),
            int256(1601310),
            int256(10981),
            int256(994446),
            int256(198535),
            int256(-250008),
            int256(-81791),
            int256(-71866)
        ];
        (, bool flagged) = model.infer(raw);
        (int256 logit, uint8 reason) = model.screen(raw);
        assertFalse(flagged);
        assertEq(logit, -1305898);
        assertEq(reason, 2);
    }

    function testFeatureOutsideClippingRangeRoutesToReview() public view {
        int256[10] memory raw;
        raw[0] = 50_000_000;
        (, uint8 reason) = model.screen(raw);
        assertEq(reason & 4, 4);
    }
}

