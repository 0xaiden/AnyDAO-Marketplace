// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./basemarket.sol";

contract FixedPrice is BaseMarket, OwnableUpgradeable {

    enum OrderSide {BUY, SELL}
    struct Order {
        address maker;
        address payment;
        address nft;
        uint256 tokenId;
        uint256 price;
        OrderSide side;
        address reserveBuyer;
        uint256 orderTime;
        uint256 duration;
        uint256 nonce;
    }

    mapping(bytes32 => Order ) public orders;

    event PlaceOrder(bytes32 _orderId, Order _order);
    event CancelOrder(bytes32 _orderId);
    event FillOrder(bytes32 _orderId, address _taker, uint256 _fee);

    function initialize(address _fund) public initializer {
        __base_init(_fund);
        __Ownable_init();
    }

    function _getOrderId(Order memory order) internal pure returns(bytes32) {
        bytes32 listId = keccak256(abi.encodePacked(order.nft, order.tokenId, order.price, order.duration, order.side, order.reserveBuyer, order.nonce));
        return listId;
    }

    function getCurrentPrice(bytes32 _orderId) public view returns(uint256) {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        return order.price;
    }

    function placeOrder(address[] memory _nfts, uint256[] memory _tokenIds, OrderSide _side, address _payment,
            uint256 _price, uint256 _startTime, uint256 _duration) external checkPayment(_payment) {
        
        if (_side == OrderSide.BUY) {
            _startTime = block.timestamp;
        }
        require(_price > 0, "FixedPrice: price is zero");
        require(_nfts.length == _tokenIds.length, "FixedPrice: length mismatch");
        require(_duration >= 5 minutes, "FixedPrice: duration < 5 minutes");
        require(_startTime >= block.timestamp, "FixedPrice: invalid start time");

        for (uint256 i=0;i<_nfts.length;++i) {
            address _nft = _nfts[i];
            uint256 _tokenId = _tokenIds[i];
            if (_side == OrderSide.SELL) {
                require(IERC721(_nft).ownerOf(_tokenId) == msg.sender, "FixedPrice: not the owner");
            }
            
            bytes32 orderId;
            Order memory order = Order({
                maker: msg.sender,
                nft: _nft,
                tokenId: _tokenId,
                payment: _payment,
                price: _price,
                side: _side,
                reserveBuyer: address(0),
                orderTime: _startTime,
                duration: _duration,
                nonce: nextNonce
            });

            orderId = _getOrderId(order);
            require(orders[orderId].maker == address(0), "FixedPrice: order existed");
            orders[orderId] = order;
            emit PlaceOrder(orderId, order);
            nextNonce += 1;
        }        
    }

    function fillOrder(bytes32 _orderId) external {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        require(block.timestamp <= (order.orderTime + order.duration), "FixedPrice: order expired");
        delete orders[_orderId];

        uint256 cost = order.price;
        uint256 fee = _computeFee(cost);

        if (order.side == OrderSide.BUY) {
            if (fee != 0) {
                fund.withdrawERC20From(order.payment, order.maker, devAddr, fee);
            }
            fund.withdrawERC20From(order.payment, order.maker, msg.sender, cost-fee);
            fund.withdrawNFTFrom(order.nft, msg.sender, order.maker, order.tokenId);
        } else {
            if (order.reserveBuyer != address(0)) {
                require(order.reserveBuyer == msg.sender, "FixedPrice: sender not from reserve buyer");
            }
            if (fee != 0) {
                fund.withdrawERC20From(order.payment, msg.sender, devAddr, fee);
            }
            fund.withdrawERC20From(order.payment, msg.sender, order.maker, cost-fee);
            fund.withdrawNFTFrom(order.nft, order.maker, msg.sender, order.tokenId);
        }
        emit FillOrder(_orderId, msg.sender, fee);
    }

    function cancelOrder(bytes32 _orderId) external {
        Order memory order = orders[_orderId];
        require(order.maker != address(0), "FixedPrice: order not exist");
        require(order.maker == msg.sender, "FixedPrice: not from the owner");
        delete orders[_orderId];
        emit CancelOrder(_orderId);
    }

}