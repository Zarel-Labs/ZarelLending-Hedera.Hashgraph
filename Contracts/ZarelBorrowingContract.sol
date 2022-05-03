// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

import "./hip-206/HederaTokenService.sol";
import "./hip-206/HederaResponseCodes.sol";

interface IERC20 {
    function transfer(address _to, uint256 _amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 _tokenId) external view returns (address);
}

contract ZarelBorrow is HederaTokenService {
    int64 public floorPrice;

    IERC20 public immutable ZarelToken;
    IERC721 public immutable ZarelNFT;

    address admin;
    address NftToken;
    address ZToken;

    struct Borrower {
        uint40 time;
        int64 serialNumber;
        int64 balance;
        bool isActive;
        address lender;
    }
    mapping(address => Borrower) public BorrowerDetails;

    constructor(
        address _admin,
        address _tokenAddr,
        address _NFTAddr,
        address _NFTToken,
        address _ZToken
    ) {
        admin = _admin;
        ZarelToken = IERC20(_tokenAddr);
        ZarelNFT = IERC721(_NFTAddr);
        NftToken = _NFTToken;
        ZToken = _ZToken;
    }

    modifier onlyAdmin() {
        admin == msg.sender;
        _;
    }

    modifier IsMember(address sender) {
        require(ZarelNFT.balanceOf(sender) > 0, "not a Zarel member");
        _;
    }

    function Borrow(address sender, int64 _serialNumber)
        public
        IsMember(sender)
        returns (bool)
    {
        Borrower storage b = BorrowerDetails[sender];
        uint256 Id = uint64(_serialNumber);
        require(sender == ZarelNFT.ownerOf(Id), "Not owner of this NFT");
        require(!b.isActive, "You have an active loan");

        // receive zarel Nft as collateral for token
        int256 response = HederaTokenService.transferNFT(
            NftToken,
            sender,
            address(this),
            _serialNumber
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("NFT Transfer Failed");
        }
        // transfer zarel token to user
        require(
            ZarelToken.transfer(sender, uint64(floorPrice)),
            "Token transfer failed"
        );
        // updater lender details
        b.balance = floorPrice;
        b.time = uint40(block.timestamp);
        b.serialNumber = _serialNumber;
        b.lender = sender;
        b.isActive = true;

        return true;
    }

    function payBack(address receiver, int64 _amount) public {
        Borrower storage b = BorrowerDetails[msg.sender];
        require(b.isActive == true, "You do not have a loan");
        require(_amount >= b.balance, "not money owned");

        int256 response = HederaTokenService.transferToken(
            ZToken,
            receiver,
            address(this),
            _amount
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Token Transfer Failed");
        }

        int256 response2 = HederaTokenService.transferNFT(
            NftToken,
            address(this),
            receiver,
            b.serialNumber
        );

        if (response2 != HederaResponseCodes.SUCCESS) {
            revert("NFT Transfer Failed");
        }

        b.isActive = false;
    }

    function setFloorPrice(int64 _floorPrice) public onlyAdmin returns (int64) {
        floorPrice = _floorPrice;
        return floorPrice;
    }

    function TokenBalance() public view onlyAdmin {
        ZarelToken.balanceOf(address(this));
    }

    function NFTBalance() public view onlyAdmin {
        ZarelNFT.balanceOf(address(this));
    }

    function getNFts(int64 serialNumber) public onlyAdmin {
        int256 response2 = HederaTokenService.transferNFT(
            NftToken,
            address(this),
            admin,
            serialNumber
        );

        if (response2 != HederaResponseCodes.SUCCESS) {
            revert("NFT Transfer Failed");
        }
    }

    function tokenAssociate(address _address) external onlyAdmin {
        int256 response = HederaTokenService.associateToken(
            address(this),
            _address
        );

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Associate Failed");
        }
    }

    // Fix the lending time calc
}
