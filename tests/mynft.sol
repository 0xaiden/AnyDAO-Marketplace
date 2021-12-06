// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {

    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://accessifi.io/";
    }

    function totalSupply() public view returns(uint256) {
        return _tokenIds.current();
    }

    function mint(address to, bytes memory data) public onlyOwner returns(uint256) {
        uint256 tokenId = _tokenIds.current();
        _safeMint(to, tokenId, data);
        _tokenIds.increment();
        return tokenId;
    }

    function _beforeTokenTransfer(address, address, uint256 tokenId) internal virtual override {
        // require(tokenId == 888, "MyNFT: invalid tokenid");
    }

    function erc165Interface() public pure returns(bytes4) {
        // return this.supportsInterface.selector;
        return type(IERC165).interfaceId;
    }

    // function interfaceId() public returns (bytes4) {
    //     return type(ERC721).interfaceId;
    // }

}