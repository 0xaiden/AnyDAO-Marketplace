// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../nftfund.sol";


abstract contract BaseMarket is Initializable {
    
    uint256 nextNonce;
    NFTFund fund;
    address devAddr;
    uint256 feeRatio; // div 10000

    function __base_init(address _fund) public initializer {
        require(_fund != address(0), "BaseMarket: _fund can not be zero address.");
        nextNonce = 0;
        fund = NFTFund(_fund);
        devAddr = msg.sender;
        // feeRatio = 100; // 1%
    }

    modifier checkPayment(address _payment) {
        require(fund.availablePayments(_payment), "BaseMarket: invalid payment");
        _;
    }

    modifier onlyDev() {
        require(devAddr == msg.sender, "BaseMarket: msg not from devAddr");
        _;
    }

    function setDevAddr(address _devAddr) external onlyDev {
        require(_devAddr != address(0), "BaseMarket: invalid address");
        devAddr = _devAddr;
    }

    function setFeeRatio(uint256 _feeRatio) external onlyDev {
        require(_feeRatio < 10000, "BaseMarket: invalid _feeRatio");
        feeRatio = _feeRatio;
    }

    function _computeFee(uint256 _cost) internal view returns(uint256) {
        uint256 fee = _cost * feeRatio / 10000;
        return fee;
    }
}