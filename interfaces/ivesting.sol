// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

interface IVesting {

    function claimable(address _nft, uint256 _tokenId, uint256 _lockedAmount, uint256 _claimedAmount) external view returns(uint256);
    
    function name() external pure returns(bytes32);

}