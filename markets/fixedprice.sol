// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./basemarket.sol";

contract FixedPrice is BaseMarket, OwnableUpgradeable {

    enum OrderSide {BUY, SELL}
    struct Order {
        address maker;
        address payment;
        address[] nfts;
        uint256[] tokenIds;
        uint256 price;
        OrderSide side;
        address reserveBuyer;
        uint256 auctionTime;
        uint256 duration;
        uint256 nonce;
    }

    mapping(bytes32 => Order ) public orders;

    event PlaceOrder(bytes32 _orderId, address _owner, address[] _nfts, uint256[] _tokenIds, address _payment, 
        address _reserveBuyer, uint256 _price, uint256 _duration, OrderSide _side, uint256 _nonce);
    event CancelOrder(bytes32 _orderId);
    event FillOrder(bytes32 _orderId, address _taker, uint256 _fee);

    function initialize(address _fund) public initializer {
        __base_init(_fund);
        __Ownable_init();
    }

    function _getOrderId(Order memory order) internal pure returns(bytes32) {
        bytes32 listId = keccak256(abi.encodePacked(order.nfts, order.tokenIds, order.price, order.duration, order.nonce));
        return listId;
    }

    function getCurrentPrice(bytes32 _orderId) public view returns(uint256) {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        return order.price;
    }

    function placeOrder(address[] memory _nfts, uint256[] memory _tokenIds, OrderSide _side, address _payment, address _reserveBuyer,
            uint256 _price, uint256 _duration) external {
        require(_price > 0, "FixedPrice: price is zero");
        require(_nfts.length == _tokenIds.length, "FixedPrice: length mismatch");
        require(_duration > 5 minutes, "FixedPrice: duration should great than 5 minutes");
        if (_side == OrderSide.BUY) {
            require(_reserveBuyer == address(0), "FixedPrice: reserveBuyer should be zero address for buy order");
            fund.depositERC20(_payment, msg.sender, _price);
        } else {
            fund.depositNFTs(_nfts, msg.sender, _tokenIds);
        }

        bytes32 orderId;
        {
            Order memory order = Order({
                maker: msg.sender,
                nfts: _nfts,
                tokenIds: _tokenIds,
                payment: _payment,
                price: _price,
                side: _side,
                reserveBuyer: _reserveBuyer,
                auctionTime: block.timestamp,
                duration: _duration,
                nonce: nextNonce
            });

            orderId = _getOrderId(order);
            require(orders[orderId].maker == address(0), "FixedPrice: order existed");
            orders[orderId] = order;
        }
        
        emit PlaceOrder(orderId, msg.sender, _nfts, _tokenIds, _payment, _reserveBuyer, _price, _duration, _side, nextNonce);
        nextNonce += 1;
    }

    function fillOrder(bytes32 _orderId) external {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        require(order.auctionTime+order.duration >= block.timestamp, "FixedPrice: order expired");
        delete orders[_orderId];

        uint256 cost = order.price;
        uint256 fee = _computeFee(cost);

        if (order.side == OrderSide.BUY) {
            if (fee != 0) {
                fund.withdrawERC20(order.payment, devAddr, fee);
            }
            fund.withdrawERC20(order.payment, msg.sender, cost-fee);
            fund.withdrawNFTsFrom(order.nfts, msg.sender, order.maker, order.tokenIds);
        } else {
            if (order.reserveBuyer != address(0)) {
                require(order.reserveBuyer == msg.sender, "FixedPrice: sender not from reserveBuyer");
            }
            if (fee != 0) {
                fund.withdrawERC20From(order.payment, msg.sender, order.maker, fee);
            }
            fund.withdrawERC20From(order.payment, msg.sender, order.maker, cost-fee);
            fund.withdrawNFTs(order.nfts, msg.sender, order.tokenIds);
        }
        emit FillOrder(_orderId, msg.sender, fee);
    }

    function cancelOrder(bytes32 _orderId) external {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        require(order.maker == msg.sender, "FixedPrice: not from the owner");
        delete orders[_orderId];
        if (order.side == OrderSide.BUY) {
            fund.withdrawERC20(order.payment, msg.sender, order.price);
        } else {
            fund.withdrawNFTs(order.nfts, msg.sender, order.tokenIds);
        }
        emit CancelOrder(_orderId);
    }

}