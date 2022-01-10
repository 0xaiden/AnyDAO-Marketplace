// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

struct SaftParam {
    address owner;
    address token;
    uint256 tokenAmount;
    address vesting;
    uint256 nextId;
    bool haveToken;
    string institutionName;
    string webSite;
    string description;
    string logoUri;

    uint256[] counts;
    uint256[] tokenAmounts;
}

interface IFactory {
    function devAddr() external view returns(address);

    function getSaftParam() external view returns (address, uint256, uint256, bool, string memory);

    function getSaftParam1() external view returns (string memory, string memory, string memory, address);
}