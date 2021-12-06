// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./basemarket.sol";

contract DutchAuction is BaseMarket, OwnableUpgradeable {

    struct Auction {
        address owner;
        address nft;
        uint256 tokenId;
        uint256 startPrice;
        uint256 endPrice;
        uint256 auctionTime;
        uint256 duration;
        address payment;
        uint256 nonce;
    }

    struct Bid {
        address owner;
        uint256 price;
    }

    mapping(bytes32 => Auction) auctions;
    mapping(bytes32 => Bid[]) bids;

    event AuctionCreated(bytes32 _listId, address _owner, address _nft, uint256 _tokenId
        , uint256 _startPrice, uint256 _endPrice, address _payment, uint256 _startTime, uint256 _duration, uint256 _nonce);
    event AuctionCanceled(bytes32 _listId);
    event DutchBuy(address _owner, bytes32 _listId, uint256 _price, uint256 _fee);

    function initialize(address _fund) initializer public {
        __base_init(_fund);
        __Ownable_init();
    }

    function _getCurrentPrice(Auction memory auction) public view returns(uint256) {
        uint256 a = auction.startPrice - auction.endPrice;
        uint256 _now = block.timestamp;
        if (_now > (auction.auctionTime + auction.duration)) {
            _now = auction.auctionTime + auction.duration;
        }
        uint256 priceDec = (_now - auction.auctionTime) * a / auction.duration;
        return auction.startPrice - priceDec;
    }

    function getCurrentPrice(bytes32 _listId) public view returns(uint256) {
        Auction memory auction = auctions[_listId];
        return _getCurrentPrice(auction);
    }

    function _getAuctionId(Auction memory _auction) internal pure returns(bytes32) {
        bytes32 listId = keccak256(abi.encodePacked(_auction.nft, _auction.tokenId, _auction.startPrice, _auction.duration, _auction.nonce));
        return listId;
    }

    function _expiredAt(Auction memory auction) internal pure returns(uint256) {
        return auction.auctionTime+auction.duration;
    }

    function createAuction(address _nft, uint256 _tokenId, uint256 _startPrice, uint256 _endPrice, 
            address _payment, uint256 _startTime, uint256 _duration) public checkPayment(_payment) {
        require(_duration >= 5 minutes, "DutchAuction: invalid duration");
        require(_startPrice > _endPrice, "DutchAuction: invalid price");
        require(_startTime > block.timestamp, "DutchAuction: invalid start time");
        require(IERC721(_nft).ownerOf(_tokenId) == msg.sender, "DucthAuction: not the owner");
        uint256 _nonce = nextNonce;
        Auction memory auction = Auction({
            owner: msg.sender,
            nft: _nft,
            tokenId: _tokenId,
            startPrice: _startPrice,
            endPrice: _endPrice,
            auctionTime: _startTime,
            payment: _payment,
            duration: _duration,
            nonce: _nonce
        });
        bytes32 listId = _getAuctionId(auction);
        auctions[listId] = auction;
        nextNonce += 1;
        emit AuctionCreated(listId, msg.sender, _nft, _tokenId, _startPrice, _endPrice, _payment, _startTime, _duration, _nonce);
    }

    function cancelAuction(bytes32 listId) public {
        Auction memory auction = auctions[listId];
        require(auction.owner != address(0), "DutchAuction: auction is expired");
        require(auction.owner == msg.sender, "DutchAuction: msg not from auction owner");
        delete auctions[listId];
        emit AuctionCanceled(listId);
    }

    function buy(bytes32 _listId) public {
        Auction memory auction = auctions[_listId];
        require(_expiredAt(auction) >= block.timestamp, "DutchAuction: auction is expired");
        delete auctions[_listId];

        uint256 currentPrice = _getCurrentPrice(auction);
        uint256 fee = _computeFee(currentPrice);
        if (fee != 0) {
            fund.withdrawERC20From(auction.payment, msg.sender, devAddr, fee);
        }
        fund.withdrawERC20From(auction.payment, msg.sender, auction.owner, currentPrice-fee);
        fund.withdrawNFTFrom(auction.nft, auction.owner, msg.sender, auction.tokenId);
        emit DutchBuy(msg.sender, _listId, currentPrice, fee);
    }

}