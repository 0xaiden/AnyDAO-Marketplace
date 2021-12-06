// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./saft.sol";
import "./interfaces/ifactory.sol";
import "./interfaces/ivesting.sol";
import "./vestings/staged.sol";
import "./vestings/onetime.sol";
import "./vestings/linearly.sol";

contract SaftFactory is OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct TokenCreator {
        address token;
        address creator;
    }

    SaftParam saftParam;
    address public acc;
    address public devAddress;
    uint256 public fee;
    
    mapping(bytes32 => address) _vestingModels;
    mapping(address => bool) _safts;
    mapping(address => uint256) public nextId;

    event CreateOnetime(address saft, SaftParam param, uint256 releaseTime);
    event CreateLinearly(address saft, SaftParam param, uint256 startTime, uint256 endTime, uint256 count);
    event CreateStaged(address saft, SaftParam param, uint256[] releaseTimes, uint256[] releaseAmounts);
    event Blacked(address addr);

    function initialize(address _acc, address _devAddr) public initializer {
        __Ownable_init();
        acc = _acc;
        devAddress = _devAddr;
    }

    modifier chargeFee() {
        if (fee != 0) {
            IERC20Upgradeable(acc).safeTransferFrom(msg.sender, address(this), fee);
        }
       _;
    }

    function devAddr() external view returns(address) {
        return devAddress;
    }

    function black(address addr) public onlyOwner {
        emit Blacked(addr);
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function claimFee(address to) public onlyOwner {
        require(IERC20Upgradeable(acc).transfer(to, IERC20Upgradeable(acc).balanceOf(address(this))));
    }

    function addVesting(address addr) public {
        _vestingModels[IVesting(addr).name()] = addr;
    }

    function getSaftParam() external view returns (address, uint256, uint256, bool, string memory) {
        return (saftParam.owner, saftParam.tokenAmount, saftParam.nextId, saftParam.haveToken, saftParam.institutionName);
    }

    function getSaftParam1() external view returns ( string memory, string memory, string memory, address) {
        return (saftParam.webSite, saftParam.description, saftParam.logoUri, saftParam.vesting);
    }

    function _createSaft(SaftParam memory param, bytes32 _vesting) internal returns(address) {
        require(param.counts.length == param.tokenAmounts.length, "SaftFactory: length mismatch");
        param.vesting = _vestingModels[_vesting];
        require(param.vesting != address(0), "SaftFactory: invalid vesting");
        {
            uint256 _tokenAmount = 0;
            for (uint256 i=0;i<param.tokenAmounts.length;++i) {
                _tokenAmount += (param.tokenAmounts[i] * param.counts[i]);
            }
            param.tokenAmount = _tokenAmount;
        }
        
        param.nextId = nextId[param.token];
        saftParam = param;
        Saft saft = new Saft(param.token);
        if (param.haveToken) {
            IERC20Upgradeable(param.token).safeTransferFrom(msg.sender, address(saft), param.tokenAmount);
        }
        
        for(uint256 i=0;i<param.counts.length;++i) {
            uint256 count = param.counts[i];
            uint256 tokenAmount = param.tokenAmounts[i];
            nextId[param.token] += count;
            for (uint256 j=0;j<count;++j) {
               saft.mintSaft(param.owner, tokenAmount);
            }
        }
        return address(saft);
    }

    function createOnetime(SaftParam memory param, uint256 releaseTime) public chargeFee {
        require(releaseTime > block.timestamp, "SaftFactory: release time < now");
        address saft = _createSaft(param, 0x0000000000000000000000000000000000000000000000000000000000000001);
        Onetime(saftParam.vesting).add(saft, releaseTime);
        emit CreateOnetime(saft, saftParam, releaseTime);
        delete saftParam;
    }

    function createLinearly(SaftParam memory param, uint256 startTime, uint256 endTime, uint256 count) public chargeFee {
        require(startTime > block.timestamp, "SaftFactory: start time < now");
        address saft = _createSaft(param, 0x0000000000000000000000000000000000000000000000000000000000000002);
        Linearly(saftParam.vesting).add(saft, startTime, endTime, count);
        emit CreateLinearly(saft, param, startTime, endTime, count);
        delete saftParam;
    }

    function createStaged(SaftParam memory param, uint256[] memory releaseTimes, uint256[] memory releaseAmounts) public chargeFee {
        require(releaseTimes.length == releaseAmounts.length, "SaftFactory: length mismatch");
        address saft = _createSaft(param, 0x0000000000000000000000000000000000000000000000000000000000000003);
        {
            uint256 _releaseAmount = 0;
            for (uint256 i=0;i<releaseAmounts.length;++i) {
                _releaseAmount += releaseAmounts[i];
            }
            require(_releaseAmount == saftParam.tokenAmount, "SaftFactory: amount mismatch");
        }
        Staged(param.vesting).add(saft, releaseTimes, releaseAmounts);
        emit CreateStaged(saft, param, releaseTimes, releaseAmounts);
        delete saftParam;
    }
}