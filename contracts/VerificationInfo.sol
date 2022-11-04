// SPDX-License-Identifier: GPL-2.0-or-later


pragma solidity ^0.8.0;

abstract contract VerificationInfo {
    struct VerificationData {
        address from;
        address to;
        address token;
        uint256 amount;
    }    
}

