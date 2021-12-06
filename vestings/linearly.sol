// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./basevesting.sol";

contract Linearly is BaseVesting {

    struct LinearlyItem {
        uint256 startTime;
        uint256 endTime;
        uint256 count;
    }

    mapping(address => LinearlyItem) items;

    constructor(address _factory) BaseVesting(_factory) {
    }

    function name() external pure virtual override returns(bytes32) {
        return 0x0000000000000000000000000000000000000000000000000000000000000002;
    }

    function add(address saft, uint256 startTime, uint256 endTime, uint256 count) public onlyFactory {
        items[saft] = LinearlyItem({
            startTime: startTime,
            endTime: endTime,
            count: count
        });
    }

    function claimable(address _saft, uint256 /*_tokenId*/, uint256 _lockedAmount, uint256 _claimedAmount) external view virtual override returns(uint256) {
        LinearlyItem memory item = items[_saft];
        uint256 _now = block.timestamp;
        if (_now < item.startTime) {
            return 0;
        }

        if (_now > item.endTime) {
            _now = item.endTime;
        }
        uint256 idx = (_now - item.startTime) * item.count / (item.endTime - item.startTime);
        return idx * _lockedAmount / item.count - _claimedAmount;
    }

}