// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface ISaft {
    function mintSaft(address _to, uint256 _lockedAmount) external returns(uint256);
}