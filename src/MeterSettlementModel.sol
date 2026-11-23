// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract MeterSettlementModel {
    int256 internal constant SCALE = 1000000;
    int256 internal constant LOGIT_CUTOFF_Q = -1236763;
    int256 public constant REVIEW_MARGIN_Q = 250000;

    function infer(int256[10] memory raw) public pure returns (int256 logitQ, bool flagged) {
        (logitQ, flagged,) = _infer(raw);
    }

    function screen(int256[10] memory raw) public pure returns (int256 logitQ, uint8 reviewReason) {
        bool flagged;
        bool outsideModelRange;
        (logitQ, flagged, outsideModelRange) = _infer(raw);
        if (flagged) reviewReason |= 1;
        if (logitQ >= LOGIT_CUTOFF_Q - REVIEW_MARGIN_Q && logitQ < LOGIT_CUTOFF_Q + REVIEW_MARGIN_Q) {
            reviewReason |= 2;
        }
        if (outsideModelRange) reviewReason |= 4;
    }

    function _infer(int256[10] memory raw) private pure returns (int256 logitQ, bool flagged, bool outsideModelRange) {
        int256[10] memory meanQ = [
            int256(-167781),
            int256(39426),
            int256(501434),
            int256(1858397),
            int256(135559),
            int256(676007),
            int256(183867),
            int256(504615),
            int256(-266728),
            int256(-665050)
        ];
        int256[10] memory invStdQ = [
            int256(1105704),
            int256(6799533),
            int256(2857425),
            int256(910339),
            int256(6050508),
            int256(2310738),
            int256(6904005),
            int256(2529191),
            int256(517002),
            int256(274762)
        ];
        int256[80] memory w1Q = [
            int256(1649539),
            int256(-2654869),
            int256(1221809),
            int256(780460),
            int256(-120262),
            int256(-66783),
            int256(-814988),
            int256(162534),
            int256(960063),
            int256(1523964),
            int256(139900),
            int256(-2323593),
            int256(431409),
            int256(321000),
            int256(-319332),
            int256(172405),
            int256(-674748),
            int256(20325),
            int256(-212516),
            int256(206343),
            int256(-1006449),
            int256(-2367748),
            int256(-582358),
            int256(1038171),
            int256(-950266),
            int256(1278456),
            int256(3354),
            int256(17026),
            int256(868672),
            int256(-342201),
            int256(-27134),
            int256(1778113),
            int256(1767066),
            int256(2092893),
            int256(92967),
            int256(-189671),
            int256(-1035603),
            int256(-28313),
            int256(388338),
            int256(-168543),
            int256(-1105416),
            int256(2461543),
            int256(477890),
            int256(373034),
            int256(-546141),
            int256(536653),
            int256(-936094),
            int256(-162709),
            int256(-3229014),
            int256(-2139736),
            int256(832935),
            int256(125050),
            int256(-1827356),
            int256(-824799),
            int256(-594810),
            int256(278823),
            int256(571528),
            int256(631042),
            int256(1510754),
            int256(-544943),
            int256(-1645512),
            int256(818948),
            int256(564877),
            int256(-575530),
            int256(-1909838),
            int256(1595992),
            int256(-652473),
            int256(-353923),
            int256(-4091412),
            int256(-2354872),
            int256(176757),
            int256(-2488841),
            int256(370022),
            int256(1065149),
            int256(-882426),
            int256(44026),
            int256(-672074),
            int256(203681),
            int256(397557),
            int256(864365)
        ];
        int256[8] memory b1Q = [
            int256(355684),
            int256(593575),
            int256(327482),
            int256(2531344),
            int256(788679),
            int256(216987),
            int256(-1335797),
            int256(684889)
        ];
        int256[8] memory w2Q = [
            int256(-1248208),
            int256(-417762),
            int256(-1158851),
            int256(1893088),
            int256(1428689),
            int256(1100873),
            int256(2709474),
            int256(-850049)
        ];
        int256 b2Q = 446567;
        int256[10] memory x;
        for (uint256 i; i < 10; ++i) {
            int256 z = ((raw[i] - meanQ[i]) * invStdQ[i]) / SCALE;
            if (z > 4000000 || z < -4000000) outsideModelRange = true;
            if (z > 4000000) z = 4000000;
            if (z < -4000000) z = -4000000;
            x[i] = z;
        }
        int256[8] memory hidden;
        for (uint256 j; j < 8; ++j) {
            int256 acc;
            for (uint256 i; i < 10; ++i) {
                acc += w1Q[j * 10 + i] * x[i];
            }
            int256 value = b1Q[j] + acc / SCALE;
            hidden[j] = value > 0 ? value : int256(0);
        }
        int256 outputAcc;
        for (uint256 j; j < 8; ++j) {
            outputAcc += w2Q[j] * hidden[j];
        }
        logitQ = b2Q + outputAcc / SCALE;
        flagged = logitQ >= LOGIT_CUTOFF_Q;
    }
}
