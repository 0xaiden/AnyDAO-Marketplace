// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./basemarket.sol";

contract EnglishAuction is BaseMarket, OwnableUpgradeable {

    struct Auction {
        address owner;
        address nft;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 auctionTime;
        uint256 duration;
        address payment;
        uint256 nonce;
    }

    struct Bid {
        address owner;
        uint256 price;
    }

    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => Bid) latestBids;
    mapping(address => mapping(bytes32 => Bid) ) bids;
    uint256 priceIncrRatio; // div 10000

    event CreateAuction(bytes32 _listId, address _owner, address _nft, uint256 _tokenId, uint256 _startPrice, uint256 _reservePrice, uint256 _startTime, uint256 _duration, address _payment);
    event CancelAuction(bytes32 _listId);
    event PlaceBid(address _owner, bytes32 _listId, uint256 _price, uint256 _oldPrice);
    event CancelBid(bytes32 _listId, uint256 _price);
    event Accept(bytes32 _listId, address _bidder, uint256 _price, uint256 _fee);

    function initialize(address _fund) initializer public {
        __base_init(_fund);
        __Ownable_init();
        priceIncrRatio = 500;
    }

    function setPriceIncrRatio(uint256 _priceIncrRatio) public onlyDev {
        priceIncrRatio = _priceIncrRatio;
    }

    function _getAuctionId(Auction memory _auction) internal pure returns(bytes32) {
        bytes32 listId = keccak256(abi.encodePacked(_auction.nft, _auction.tokenId, _auction.startPrice, _auction.duration, _auction.nonce));
        return listId;
    }

    function getCurrentPrice(bytes32 _listId) public view returns(uint256) {
        return latestBids[_listId].price;
    }

    function createAuction(address _nft, uint256 _tokenId, uint256 _startPrice, uint256 _reservePrice, 
            address _payment, uint256 _startTime, uint256 _duration) public checkPayment(_payment) {
        require(_startTime > block.timestamp, "EnglishAuction: invalid start time");
        require(_duration >= 5 minutes, "EnglishAuction: duration should great than 5 minutes");
        require(_reservePrice == 0 || _reservePrice > _startPrice, "EnglishAuction: invalid reservePrice");
        require(IERC721(_nft).ownerOf(_tokenId) == msg.sender, "EnglishAuction: not the owner");
        uint256 _nonce = nextNonce;
        Auction memory auction = Auction({
            owner: msg.sender,
            nft: _nft,
            tokenId: _tokenId,
            startPrice: _startPrice,
            reservePrice: _reservePrice,
            payment: _payment,
            auctionTime: _startTime,
            duration: _duration,
            nonce: _nonce
        });
        bytes32 listId = _getAuctionId(auction);
        auctions[listId] = auction;
        nextNonce += 1;
        emit CreateAuction(listId, msg.sender, _nft, _tokenId, _startPrice, _reservePrice, _startTime, _duration, _payment);
    }

    function cancelAuction(bytes32 _listId) public {
        Auction memory auction = auctions[_listId];
        require(auction.owner != address(0), "EnglishAuction: auction does not exist");
        require(auction.owner == msg.sender, "EnglishAuction: sender is not the owner");
        // Bid memory bid = latestBids[_listId];
        // require(bid.owner == address(0), "EnglishAuction: auction is bidding");
        delete auctions[_listId];
        // delete latestBids[_listId];
        emit CancelAuction(_listId);
    }

    function _expiredAt(Auction memory auction) internal pure returns(uint256) {
        return auction.auctionTime+auction.duration;
    }

    function nextPrice(bytes32 _listId) public view returns(uint256) {
        uint256 bestBidPrice = latestBids[_listId].price;
        uint256 _nextPrice = bestBidPrice * (priceIncrRatio+10000) / 10000;
        return _nextPrice;
    }

    function placeBid(bytes32 _listId, uint256 _price) public {
        Auction memory auction = auctions[_listId];
        require(auction.owner != address(0), "EnglishAuction: auction not exist");
        require(block.timestamp <= _expiredAt(auction), "EnglishAuction: auction is expired");
        require(_price >= auction.startPrice, "EnglishAuction: invalid price");
        uint256 _nextPrice = nextPrice(_listId);
        require(_price >= _nextPrice, "EnglishAuction: invalid bid price");

        Bid storage bid = bids[msg.sender][_listId];
        if (bid.owner == address(0)) {
            bid.owner = msg.sender;
        }
        uint256 oldPrice = bid.price;
        bid.price = _price;
        latestBids[_listId] = bid;
        emit PlaceBid(msg.sender, _listId, _price, oldPrice);
    }

    function cancelBid(bytes32 _listId) public {
        Bid memory bid = bids[msg.sender][_listId];
        require(bid.owner != address(0), "EnglishAuction: bid not exist");
        require(bid.owner == msg.sender, "EnglishAuction: not from the owner");
        uint256 _price = bid.price;
        delete bids[msg.sender][_listId];
        // Auction memory auction = auctions[_listId];
        // if(bid.owner == latestBids[_listId].owner) {
        //     require(block.timestamp <= _expiredAt(auction), "EnglishAuction: best bid can not be canceled while the auction is over");
        // }
        emit CancelBid(_listId, _price);
    }

    function accept(bytes32 _listId, address _bidder) public {
        Auction memory auction = auctions[_listId];
        require(auction.owner != address(0), "EnglishAuction: auction does not exist");
        require(auction.owner == msg.sender, "EnglishAuction msg not from auction owner");
        // require(_expiredAt(auction) <= block.timestamp, "EnglishAuction: auction is not end");
        Bid memory _bid = bids[_bidder][_listId];
        require(_bid.owner != address(0), "EnglishAuction: auction is not bid");
        delete bids[_bid.owner][_listId];
        delete latestBids[_listId];
        delete auctions[_listId];

        uint256 cost = _bid.price;
        uint256 fee = _computeFee(cost);
        if (fee != 0) {
            fund.withdrawERC20From(auction.payment, _bid.owner, devAddr, fee);
        }
        fund.withdrawERC20From(auction.payment, _bid.owner, auction.owner, cost-fee);
        fund.withdrawNFTFrom(auction.nft, auction.owner, _bid.owner, auction.tokenId);
        emit Accept(_listId, _bid.owner, _bid.price, fee);
    }
}