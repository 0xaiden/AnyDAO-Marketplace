// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "./basevesting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Onetime is BaseVesting {

    mapping(address => uint256) public releaseTimes;

    constructor(address _factory) BaseVesting(_factory) {
    }

    function name() external pure virtual override returns(bytes32) {
        return 0x0000000000000000000000000000000000000000000000000000000000000001;
    }

    function add(address saft, uint256 _releaseTime) public onlyFactory {
        releaseTimes[saft] = _releaseTime;
    }

    function claimable(address _saft, uint256 /*_tokenId*/, uint256 _lockedAmount, uint256 _claimedAmount) external view virtual override returns(uint256) {
        if (block.timestamp < releaseTimes[_saft]) {
            return 0;
        }
        return _lockedAmount - _claimedAmount;
    }

}