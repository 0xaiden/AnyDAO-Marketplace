// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./basevesting.sol";

contract Staged is BaseVesting {

    struct TimeAmount {
        uint256 time;
        uint256 amount;
    }

    mapping(address => TimeAmount[]) public timeAmounts;
    
    constructor(address _factory) BaseVesting(_factory) {
    }

    function name() external pure virtual override returns(bytes32) {
        return 0x0000000000000000000000000000000000000000000000000000000000000003;
    }

    function add(address saft, uint256[] memory _releaseTimes, uint256[] memory _releaseAmounts) public onlyFactory {
        require(_releaseTimes.length == _releaseAmounts.length, "Staged: invalid length");
        uint256 lastTime = 0;
        for (uint256 i=0;i<_releaseTimes.length;++i) {
            uint256 rt = _releaseTimes[i];
            require(lastTime < rt, "Staged: invalid time");
            lastTime = rt;
            timeAmounts[saft].push(TimeAmount({
                time: rt,
                amount: _releaseAmounts[i]
            }));
        }
    }

    function claimable(address _saft, uint256 /*_tokenId*/, uint256 /*_lockedAmount*/, uint256 _claimedAmount) external view virtual override returns(uint256) {
        uint256 totalAmount = 0;
        TimeAmount[] memory _timeAmounts = timeAmounts[_saft];
        for (uint256 i=0;i<_timeAmounts.length;++i) {
            TimeAmount memory ta = _timeAmounts[i];
            if (block.timestamp < ta.time) {
                break;
            }
            totalAmount += ta.amount;
        }        
        return totalAmount - _claimedAmount;
    }

}