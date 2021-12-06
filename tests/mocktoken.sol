// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    address public minter;
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 _decimal) ERC20(name, symbol) {
        _mint(msg.sender, 10000000 ether);
        _decimals = _decimal;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "MockToken: msg not from minter");
        _;
    }

    function setMinter(address _minter) public onlyOwner {
        minter = _minter;
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        _mint(_to, _amount);
    }
}