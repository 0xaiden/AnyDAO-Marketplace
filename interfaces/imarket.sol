// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

interface IMarket {
    function getCurrentPrice() external returns(uint256);
}