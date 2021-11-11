// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./saft.sol";
import "./interfaces/ivesting.sol";
import "./vestings/staged.sol";
import "./vestings/onetime.sol";
import "./vestings/linearly.sol";

contract SaftFactory is OwnableUpgradeable {

    struct TokenCreator {
        address token;
        address creator;
    }

    address public _xKey;
    address public _devAddr;
    uint256 public _fee;
    
    mapping(bytes32 => address) _vestingModels;
    mapping(address => bool) _safts;

    event CreateOnetime(address saft, uint256 releaseTime);
    event CreateLinearly(address saft, uint256 startTime, uint256 endTime, uint256 count);
    event CreateStaged(address saft, uint256[] releaseTimes, uint256[] releaseAmounts);

    function initialize(address xkey, address devAddr) public initializer {
        __Ownable_init();
        _xKey = xkey;
        _devAddr = devAddr;
    }

    modifier chargeFee() {
        if (_fee != 0) {
            require(IERC20(_xKey).transferFrom(msg.sender, address(this), _fee), "SaftFactory: failed to deduct xkey");
        }
       _;
    }

    function setFee(uint256 fee) public onlyOwner {
        _fee = fee;
    }

    function claimFee(address to) public onlyOwner {
        require(IERC20(_xKey).transfer(to, IERC20(_xKey).balanceOf(address(this))));
    }

    function addVesting(address addr, bytes32 model) public {
        _vestingModels[model] = addr;
    }

    function _mintSafts(Saft saft, address _owner, uint256[] memory counts, uint256[] memory tokenAmounts) internal {
        require(counts.length == tokenAmounts.length, "SaftFactory: length mismatch");
        for(uint256 i=0;i<counts.length;++i) {
            uint256 count =counts[i];
            uint256 tokenAmount =tokenAmounts[i];
            for (uint256 j=0;j<count;++j) {
               saft.mintSaft(_owner, tokenAmount);
            }
        }
    }

    /*
        avoid stack too deep
        params order:
            institutionName
            projectName
            tokenTicker
            webSite
            description
            logoUri
    */
    function createOnetime(address _owner, address _token, string[] memory params, 
            uint256[] memory counts, uint256[] memory tokenAmounts, uint256 releaseTime) public chargeFee {
        
        require(params.length == 6, "SaftFactory: params length should be 6");
        bytes32 model = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address vesting = _vestingModels[model];
        require(vesting != address(0), "SaftFactory: invalid vesting");
        uint256 _tokenAmount = 0;
        for (uint256 i=0;i<tokenAmounts.length;++i) {
            _tokenAmount += tokenAmounts[i];
        }
        Saft saft = new Saft(_owner, _token, vesting, _tokenAmount, params);
        _mintSafts(saft, _owner, counts, tokenAmounts);
        Onetime(vesting).add(address(saft), releaseTime);
        emit CreateOnetime(address(saft), releaseTime);
    }

    function createLinearly(address _owner, address _token, string[] memory params, 
            uint256[] memory counts, uint256[] memory tokenAmounts, uint256 startTime, uint256 endTime, uint256 count) public chargeFee {

        address vesting;
        {
            bytes32 model = 0x0000000000000000000000000000000000000000000000000000000000000002;
            vesting = _vestingModels[model];
            require(vesting != address(0), "SaftFactory: invalid vesting");
        }

        uint256 _tokenAmount = 0;
        for (uint256 i=0;i<tokenAmounts.length;++i) {
            _tokenAmount += tokenAmounts[i];
        }
        Saft saft = new Saft(_owner, _token, vesting, _tokenAmount, params);
        _mintSafts(saft, _owner, counts, tokenAmounts);
        Linearly(vesting).add(address(saft), startTime, endTime, count);
        emit CreateLinearly(address(saft), startTime, endTime, count);
    }

    function createStaged(address _owner, address _token, string[] memory params, uint256[] memory counts, uint256[] memory tokenAmounts, 
        uint256[] memory releaseTimes, uint256[] memory releaseAmounts) public chargeFee {

        require(releaseTimes.length == releaseAmounts.length, "SaftFactory: length mismatch");
        uint256 _tokenAmount = 0;
        for (uint256 i=0;i<tokenAmounts.length;++i) {
            _tokenAmount += tokenAmounts[i];
        }

        {
            uint256 _releaseAmount = 0;
            for (uint256 i=0;i<releaseAmounts.length;++i) {
                _releaseAmount += releaseAmounts[i];
            }
            require(_releaseAmount == _tokenAmount, "SaftFactory: amount mismatch");
        }

        bytes32 model = 0x0000000000000000000000000000000000000000000000000000000000000003;
        address vesting = _vestingModels[model];
        require(vesting != address(0), "SaftFactory: invalid vesting");
        Saft saft = new Saft(_owner, _token, vesting, _tokenAmount, params);
        _mintSafts(saft, _owner, counts, tokenAmounts);
        Staged(vesting).add(address(saft), releaseTimes, releaseAmounts);
        emit CreateStaged(address(saft), releaseTimes, releaseAmounts);
    }
}