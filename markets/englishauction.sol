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

    event CreateAuction(bytes32 _listId, address _owner, address _nft, uint256 _tokenId, uint256 _startPrice, uint256 _reservePrice, uint256 _duration, address _payment, uint256 _nonce);
    event CancelAuction(bytes32 _listId);
    event PlaceBid(address _owner, bytes32 _listId, uint256 _price);
    event CancelBid(bytes32 _listId);
    event Settle(bytes32 _listId, uint256 _price, uint256 _fee);

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

    function createAuction(address _nft, uint256 _tokenId, uint256 _startPrice, uint256 _reservePrice, address _payment, uint256 _duration) public {
        require(_reservePrice == 0 || _reservePrice > _startPrice, "EnglishAuction: invalid reservePrice");
        uint256 _nonce = nextNonce;
        fund.depositNFT(_nft, msg.sender, _tokenId);
        Auction memory auction = Auction({
            owner: msg.sender,
            nft: _nft,
            tokenId: _tokenId,
            startPrice: _startPrice,
            reservePrice: _reservePrice,
            payment: _payment,
            auctionTime: block.timestamp,
            duration: _duration,
            nonce: _nonce
        });
        bytes32 listId = _getAuctionId(auction);
        auctions[listId] = auction;
        nextNonce += 1;
        emit CreateAuction(listId, msg.sender, _nft, _tokenId, _startPrice, _reservePrice, _duration, _payment, _nonce);
    }

    function cancelAuction(bytes32 _listId) public {
        Auction memory auction = auctions[_listId];
        require(auction.owner == msg.sender, "EnglishAuction: sender is not the owner");
        Bid memory bid = latestBids[_listId];
        require(bid.owner == address(0), "EnglishAuction: auction is offered");
        delete auctions[_listId];
        delete latestBids[_listId];
        fund.withdrawNFT(auction.nft, msg.sender, auction.tokenId);
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
        uint256 _nextPrice = nextPrice(_listId);
        require(_price >= _nextPrice, "EnglishAuction: invalid bid price");

        Bid storage bid = bids[msg.sender][_listId];
        uint256 priceDelta = _price - bid.price;
        if (bid.owner == address(0)) {
            bid.owner = msg.sender;
        }
        bid.price = _price;
        latestBids[_listId] = bid;
        fund.depositERC20(auction.payment, msg.sender, priceDelta);
        emit PlaceBid(msg.sender, _listId, _price);
    }

    function cancelBid(bytes32 _listId) public {
        Bid memory bid = bids[msg.sender][_listId];
        require(bid.owner != address(0), "EnglishAuction: bid not exist");
        require(bid.owner != msg.sender, "EnglishAuction: not from the owner");
        delete bids[msg.sender][_listId];
        Auction memory auction = auctions[_listId];
        fund.withdrawERC20(auction.payment, msg.sender, bid.price);
        emit CancelBid(_listId);
    }

    function settle(bytes32 _listId) public {
        Auction memory auction = auctions[_listId];
        require(auction.owner != address(0), "EnglishAuction: auction does not exist");
        require(_expiredAt(auction) <= block.timestamp, "EnglishAuction: auction is not end");
        Bid memory bestBid = latestBids[_listId];
        if (msg.sender != auction.owner) {
            require((auction.reservePrice != 0) && (bestBid.price >= auction.reservePrice), "EnglishAuction: price less than reserve price");
        }
        require(bestBid.owner != address(0), "EnglishAuction: auction is not offered");
        delete bids[bestBid.owner][_listId];
        delete latestBids[_listId];
        delete auctions[_listId];

        uint256 cost = bestBid.price;
        uint256 fee = _computeFee(cost);
        if (fee != 0) {
            fund.withdrawERC20(auction.payment, devAddr, fee);
        }
        fund.withdrawERC20(auction.payment, auction.owner, cost-fee);
        fund.withdrawNFT(auction.nft, bestBid.owner, auction.tokenId);
        emit Settle(_listId, bestBid.price, fee);
    }
}