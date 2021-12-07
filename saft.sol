// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ifactory.sol";
import "./interfaces/isaft.sol";
import "./interfaces/ivesting.sol";

interface SimpleERC20 {
    function name() external returns(string memory);
    function symbol() external returns(string memory);
}


contract Saft is ERC721, ISaft {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    // enum SaftState {DEPOSITED, VERIFIED, UNVERIFIED}

    struct NftItem {
        uint256 lockedAmount;
        uint256 claimedAmount;
    }

    address public factory;
    address public devAddr;
    address public owner;
    address public token;
    uint256 public tokenAmount;
    string public institutionName;
    string public webSite;
    string public description;
    string public logoUri;

    address public vesting;
    mapping(uint256 => NftItem) public nftItems;
    uint256 private _nextId;
    uint256 public totalSupply;
    bytes32 public iDocHash;
    bytes32 public tDocHash;
    bytes institutionSig;
    bytes teamSig;

    event ClaimItem(address _to, uint256 _amount, uint256 _id);
    event MintSaft(address _to, uint256 _tokenId, uint256 _lockedAmount);
    event Claim(address _to, uint256 _amount);
    event Verify(uint256 _nonce, uint256 _refBlockNumber, bytes32 _docHash, bytes _sig, bool _isTeam);

    constructor(address _token) ERC721(string(abi.encodePacked(SimpleERC20(_token).symbol(), "-", SimpleERC20(_token).name(), " NFT")), string(abi.encodePacked("Future-", SimpleERC20(_token).symbol()))) {
        bool haveToken = false;
        (owner, tokenAmount, _nextId, haveToken, institutionName) = IFactory(msg.sender).getSaftParam();
        if (haveToken) {
            iDocHash = 0x0000000000000000000000000000000000000000000000000000000000000001;
            tDocHash = 0x0000000000000000000000000000000000000000000000000000000000000001;
        }
        factory = msg.sender;
        token = _token;
        (webSite, description, logoUri, vesting) = IFactory(factory).getSaftParam1();
    }

    modifier onlyFactory() {
        require(factory == msg.sender, "BaseSaft: msg not from factory");
        _;
    }

    modifier onlyDev() {
        require(devAddr == msg.sender, "BaseSaft: msg not from dev addr");
        _;
    }

    // function state() public view returns(SaftState) {
    //     if (iDocHash == 0x0000000000000000000000000000000000000000000000000000000000000001) {
    //         return SaftState.DEPOSITED;
    //     }

    //     if (iDocHash == tDocHash && iDocHash != bytes32(0)) {
    //         return SaftState.UNVERIFIED;
    //     }

    //     return SaftState.UNVERIFIED;
    // }

    function transferDevAddr(address _newDev) public onlyDev {
        devAddr = _newDev;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://accessifi.io/saft/";
    }

    function energencyWithdraw(address _token, address _to, uint256 _amount) public onlyDev {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function mintSaft(address _to, uint256 _lockedAmount) external override onlyFactory returns(uint256) {
        require(_lockedAmount > 0, "BaseSaft: invalid lock amount");
        uint256 tokenId = _nextId;
        _safeMint(_to, tokenId);
        nftItems[tokenId].lockedAmount = _lockedAmount;
        _nextId += 1;
        totalSupply += 1;
        emit MintSaft(_to, tokenId, _lockedAmount);
        return tokenId;
    }

    function burnSaft(uint256 _tokenId) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "BaseSaft: no access to the token");
        NftItem memory item = nftItems[_tokenId];
        require(item.lockedAmount == 0, "BaseSaft: invalid tokenId");
        require(item.claimedAmount != item.lockedAmount, "BaseSaft: token not claimed before burn");
        _burn(_tokenId);
    }

    function underlyingBalance(uint256 _tokenId) public view returns(uint256) {
        NftItem memory item = nftItems[_tokenId];
        return item.lockedAmount - item.claimedAmount;
    }

    function totalBalance() public view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getContractAddress(address _origin, uint256 _nonce) public pure returns(address) {
        if(_nonce == 0x00)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80))))));
        if(_nonce <= 0x7f)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce))))));
        if(_nonce <= 0xff)     return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce))))));
        if(_nonce <= 0xffff)   return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce))))));
        if(_nonce <= 0xffffff) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce))))));
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce))))));
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "Saft: invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function verify(uint256 nonce, uint256 refBlockNumber, bytes32 _docHash, bytes memory sig) public {
        require((refBlockNumber >= (block.number-50)) && (refBlockNumber < (block.number + 50)), "BaseSaft: invalid ref block number");
        require(iDocHash != 0x0000000000000000000000000000000000000000000000000000000000000001, "BaseSaft: deposited");
        if (iDocHash == tDocHash) {
            require(iDocHash == bytes32(0), "BaseSaft: verified");
        }

        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19Ethereum Signed Message:\n32',
                keccak256(abi.encode(_docHash, refBlockNumber))
            )
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
        address addr = ecrecover(digest, v, r, s);
        address contractAddr = getContractAddress(addr, nonce);
        if (contractAddr == token) {
            teamSig = sig;
            tDocHash = _docHash;
        } else {
            require(addr == owner, "Saft: invalid sig");
            institutionSig = sig;
            iDocHash = _docHash;
        }
        emit Verify(nonce, refBlockNumber, _docHash, sig, contractAddr == token);
    }

    function _claimable(uint256 _tokenId, uint256 _lockedAmount, uint256 _claimedAmount) internal view virtual returns(uint256) {
        return IVesting(vesting).claimable(address(this), _tokenId, _lockedAmount, _claimedAmount);
    }

    function claimable(uint256 _tokenId) public view returns(uint256) {
        NftItem memory item = nftItems[_tokenId];
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amount = _claimable(_tokenId, item.lockedAmount, item.claimedAmount);
        return balance > amount ? amount : balance;
    }

    function claim(uint256[] memory _ids, address _to, uint256 _amount) public returns(uint256) {
        require(_ids.length !=0, "Saft: no nft to claim");
        uint256 toClaim = _amount;
        for(uint256 i=0;i<_ids.length;++i) {
            uint256 _id = _ids[i];
            require(ownerOf(_id) == msg.sender, "Saft: not the owner");
            NftItem storage item = nftItems[_id];
            uint256 amt = _claimable(_id, item.lockedAmount, item.claimedAmount);
            require(amt != 0, "BaseSaft: not able to claim 0");
            if (amt < toClaim) {
                item.claimedAmount += amt;
                toClaim -= amt;
                emit ClaimItem(_to, amt, _id);
            } else {
                item.claimedAmount += toClaim;
                emit ClaimItem(_to, toClaim, _id);
                toClaim = 0;
                break;
            }
        }

        require(toClaim == 0, "Saft: claim too much");
        IERC20(token).safeTransfer(_to, _amount);
        emit Claim(_to, _amount);
        return _amount;
    }
    
}