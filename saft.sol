// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/isaft.sol";
import "./interfaces/ivesting.sol";

interface SimpleERC20 {
    function name() external returns(string memory);
    function symbol() external returns(string memory);
}

contract Saft is ERC721, ISaft {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    struct NftItem {
        uint256 lockedAmount;
        uint256 claimedAmount;
    }

    address public factory;
    address public owner;
    address public token;
    uint256 public tokenAmount;
    string public institutionName;
    string public projectName;
    string public tokenTicker;
    string public webSite;
    string public description;
    string public logoUri;

    IVesting public vesting;
    mapping(uint256 => NftItem) public nftItems;
    Counters.Counter private _nextId;
    bytes32 docHash;
    bytes institutionSig;
    bytes teamSig;

    event ClaimItem(address _to, uint256 _amount, uint256 _id);
    event MintSaft(uint256 _tokenId, uint256 _lockedAmount);
    event Claim(address _to, uint256 _amount);
    event Verify(uint256 _nonce, uint256 _refBlockNumber, bytes32 _docHash, bytes _sig, bool _isTeam);

    constructor(address _owner, address _token, address _vesting,
            uint256 _tokenAmount, string[] memory _params) ERC721(SimpleERC20(_token).name(), SimpleERC20(_token).symbol()) {
        factory = msg.sender;
        owner = _owner;
        token = _token;
        tokenAmount = _tokenAmount;
        institutionName = _params[0];
        projectName = _params[1];
        tokenTicker = _params[2];
        webSite = _params[3];
        description = _params[4];
        logoUri = _params[5];
        vesting = IVesting(_vesting);
    }

    modifier onlyFactory() {
        require(factory == msg.sender, "BaseSaft: msg not from factory");
        _;
    }

    function totalSupply() public view returns(uint256) {
        return _nextId.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://xplanet.io/saft/";
    }

    function mintSaft(address _to, uint256 _lockedAmount) external override onlyFactory returns(uint256) {
        require(_lockedAmount > 0, "BaseSaft: invalid lock amount");
        uint256 tokenId = _nextId.current();
        _safeMint(_to, tokenId);
        nftItems[tokenId].lockedAmount = _lockedAmount;
        _nextId.increment();
        emit MintSaft(tokenId, _lockedAmount);
        return tokenId;
    }

    function burnSaft(uint256 _tokenId) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "BaseSaft: no access to the token");
        NftItem memory item = nftItems[_tokenId];
        require(item.lockedAmount == 0, "BaseSaft: invalid tokenId");
        require(item.claimedAmount != 0, "BaseSaft: token not claimed before burn");
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
        if (docHash == bytes32(0)) {
            docHash = _docHash;
        } else {
            require(docHash == _docHash, "Saft: invalid doc hash");
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
        } else {
            require(addr == owner, "Saft: invalid sig");
            institutionSig = sig;
        }
        emit Verify(nonce, refBlockNumber, _docHash, sig, contractAddr == token);
    }

    function _claimable(uint256 _tokenId, uint256 _lockedAmount, uint256 _claimedAmount) internal view virtual returns(uint256) {
        return IVesting(vesting).claimable(address(this), _tokenId, _lockedAmount, _claimedAmount);
    }

    function claimable(uint256 _tokenId) public view returns(uint256) {
        NftItem memory item = nftItems[_tokenId];
        return _claimable(_tokenId, item.lockedAmount, item.claimedAmount);
    }

    function claim(uint256[] memory _ids, address _to, uint256 _amount) public returns(uint256) {
        require(_ids.length !=0, "Saft: no nft to claim");
        uint256 toClaim = _amount;
        for(uint256 i=0;i<_ids.length;++i) {
            uint256 _id = _ids[i];
            NftItem storage item = nftItems[_id];
            uint256 amt = _claimable(_id, item.lockedAmount, item.claimedAmount);
            require(amt != 0, "BaseSaft: not able to claim 0");
            if (amt <= toClaim) {
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