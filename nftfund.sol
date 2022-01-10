// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract NFTFund is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) markets;
    mapping(address => bool) public availablePayments;

    event DepositERC20(address _token, address _from, uint256 _amount);
    event WithdrawERC20(address _token, address _to, uint256 _amount);

    event DepositNFT(address _token, address _from, uint256 _tokenId);
    event DepositNFTs(address[] _token, address _from, uint256[] _tokenIds);
    event WithdrawNFT(address _token, address _to, uint256 _tokenId);
    event WithdrawNFTs(address[] _token, address _to, uint256[] _tokenIds);
    event AddMarket(address _owner, address _market);
    event RemoveMarket(address _owner, address _market);
    event SetPayment(address _payment, bool _oldStatus, bool _status);

    constructor() {
    }

    modifier isFromMarket(address _market) {
        require(markets[_market], "NFTFund: not from existed market");
        _;
    }

    modifier isValidPayment(address _payment) {
        require(availablePayments[_payment], "BaseMarket: invalid payment");
        _;
    }

    function setPayment(address _payment, bool _status) public onlyOwner {
        bool oldStatus = availablePayments[_payment];
        availablePayments[_payment] = _status;
        emit SetPayment(_payment, oldStatus, _status);
    }

    function addMarket(address _market) public onlyOwner {
        markets[_market] = true;
        emit AddMarket(msg.sender, _market);
    }

    function removeMarket(address _market) public onlyOwner {
        markets[_market] = false;
        emit RemoveMarket(msg.sender, _market);
    }

    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external virtual override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function depositERC20(address _token, address _from, uint256 _amount) public isFromMarket(msg.sender) isValidPayment(_token) {
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        emit DepositERC20(_token, _from, _amount);
    }

    function withdrawERC20(address _token, address _to, uint256 _amount) public isFromMarket(msg.sender) isValidPayment(_token) {
        IERC20(_token).safeTransfer(_to, _amount);
        emit WithdrawERC20(_token, _to, _amount);
    }

    function withdrawERC20From(address _token, address _from, address _to, uint256 _amount) public isFromMarket(msg.sender) isValidPayment(_token) {
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        emit WithdrawERC20(_token, _to, _amount);
    }

    function depositNFT(address _nft, address _from, uint256 _tokenId) public isFromMarket(msg.sender) {
        IERC721(_nft).safeTransferFrom(_from, address(this), _tokenId, "");
        emit DepositNFT(_nft, _from, _tokenId);
    }

    function withdrawNFT(address _nft, address _to, uint256 _tokenId) public isFromMarket(msg.sender) {
        require(_to != address(0), "NFTFund: zero address found");
        IERC721(_nft).safeTransferFrom(address(this), _to, _tokenId);
        emit WithdrawNFT(_nft, _to, _tokenId);
    }

    function withdrawNFTFrom(address _nft, address _from, address _to, uint256 _tokenId) public isFromMarket(msg.sender) {
        require(_to != address(0), "NFTFund: zero address found");
        IERC721(_nft).safeTransferFrom(_from, _to, _tokenId);
        emit WithdrawNFT(_nft, _to, _tokenId);
    }


    function depositNFTs(address[] memory _nfts, address _from, uint256[] memory _tokenIds) public isFromMarket(msg.sender) {
        require(_nfts.length==_tokenIds.length, "NFTFund: _nfts.length and _tokenIds.length are not same");
        for (uint256 i=0;i<_nfts.length;++i) {
            IERC721(_nfts[i]).safeTransferFrom(_from, address(this), _tokenIds[i], "");
        }
        emit DepositNFTs(_nfts, _from, _tokenIds);
    }

    function withdrawNFTs(address[] memory _nfts, address _to, uint256[] memory _tokenIds) public isFromMarket(msg.sender) {
        require(_nfts.length==_tokenIds.length, "NFTFund: _nfts.length and _tokenIds.length are not same");
        require(_to != address(0), "NFTFund: zero address found");
        for (uint256 i=0;i<_nfts.length;++i) {
            IERC721(_nfts[i]).safeTransferFrom(address(this), _to, _tokenIds[i]);
        }
        emit WithdrawNFTs(_nfts, _to, _tokenIds);
    }

    function withdrawNFTsFrom(address[] memory _nfts, address _from, address _to, uint256[] memory _tokenIds) public isFromMarket(msg.sender) {
        require(_nfts.length==_tokenIds.length, "NFTFund: _nfts.length and _tokenIds.length are not same");
        require(_to != address(0), "NFTFund: zero address found");
        for (uint256 i=0;i<_nfts.length;++i) {
            IERC721(_nfts[i]).safeTransferFrom(_from, _to, _tokenIds[i]);
        }
        emit WithdrawNFTs(_nfts, _to, _tokenIds);
    } 
}