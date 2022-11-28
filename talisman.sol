// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyMinted();
error InvalidBlockNumber();
error BlockNumberTooOld();
error InvalidSignature();

contract Talisman is Ownable, ERC721A {
    using ECDSA for bytes32;
    using Strings for uint256;

    string imageURI;
    string animationURI;
    string description;
    address chipAddress;
    uint256 maxBlockMint;

    event adminMinted(address indexed recipient, uint256 indexed quantity);
    event chipAddressUpdated(address indexed newChipAddress, address indexed prevChipAddress);
    event metaDataUpdated(string indexed _imageURI, string indexed _animationURI, string indexed _description);

    constructor(
        address _chipAddress, 
        uint256 _maxBlockMint, 
        uint256 _mintAmount,
        string memory _imageURI,
        string memory _animationURI,
        string memory _description
        ) ERC721A("Black Jade Talisman Card", "BJTC") 
    {
        chipAddress = _chipAddress;
        maxBlockMint = _maxBlockMint;
        adminMint(_mintAmount);
        imageURI = _imageURI;
        animationURI = _animationURI;
        description = _description;
    }

    function mint(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig) external payable {
        // Max mint of 1 NFT per address
        if(_numberMinted(msg.sender) >= 1) {
            revert AlreadyMinted();
        }

        // The blockNumberUsedInSig must be in a previous block because the blockhash of the current
        // block does not exist yet.
        if (block.number <= blockNumberUsedInSig) {
            revert InvalidBlockNumber();
        }

        unchecked {
            if (block.number - blockNumberUsedInSig > maxBlockMint) {
                revert BlockNumberTooOld();
            }
        }

        bytes32 blockHash = blockhash(blockNumberUsedInSig);
        bytes32 signedHash = keccak256(abi.encodePacked(_msgSender(), blockHash)).toEthSignedMessageHash();
        address signerAddress = signedHash.recover(signatureFromChip);

        if(signerAddress != chipAddress) {
            revert InvalidSignature();
        }

        _mint(msg.sender, 1);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "Black Jade Talisman Card ', tokenId.toString(), '",',
                '"description": "', description,'", ',
                '"image": "', imageURI,'", ',
                '"animation_url": "', animationURI,'" '
            '}'
        );
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(dataURI)
        ));
    }


    function adminMint(uint256 _quantity) public onlyOwner {
        _mint(msg.sender, _quantity);
        emit adminMinted(msg.sender, _quantity);
    }

    function updateChipAddress(address _newChipAddress) public onlyOwner {
        address prevChipAddress = chipAddress;
        chipAddress = _newChipAddress;
        emit chipAddressUpdated(_newChipAddress, prevChipAddress);
    }

    function updateMetadata(
        string memory _imageURI,
        string memory _animationURI,
        string memory _description) public onlyOwner 
    {
        imageURI = _imageURI;
        animationURI = _animationURI;
        description = _description;

        emit metaDataUpdated(imageURI, animationURI, description);
    }
}