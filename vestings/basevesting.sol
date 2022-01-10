// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "../interfaces/ivesting.sol";

abstract contract BaseVesting is IVesting {
    address public factory;
    constructor(address _factory) {
        require(_factory != address(0), "BaseVesting: _factory can not be zero address.");
        factory = _factory;
    }

    modifier onlyFactory() {
        require(factory == msg.sender, "BaseVesting: msg not from factory");
        _;
    }

    function claimable(address /*_saft*/, uint256 /*_tokenId*/, uint256 /*_lockedAmount*/, uint256 /*_claimedAmount*/) external view virtual override returns(uint256) {
        return 0;
    }

}