// SPDX-License-Identifier: Unlicense
//Добавить чтобы купленнаая нфт не был на продаже
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {

    using Counters for Counters.Counter;
    // _tokenIds variable has the most recent minted tokenId
    Counters.Counter private _tokenIds;
    // Keeps track of the number of items sold on the marketplace
    Counters.Counter private _itemsSold;
    // owner is the contract address that created the smart contract
    address payable owner;
    // The fee charged by the marketplace to be allowed to list an NFT
    uint256 listPrice = 0.01 ether;

    // The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    // Mapping to store tokenId to token info
    mapping(uint256 => ListedToken) private idToListedToken;

    // Events
    event TokenListedSuccess(uint256 indexed tokenId, address owner, address seller, uint256 price, bool currentlyListed);
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice); 

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function updateListPrice(uint256 _listPrice) public payable {
        require(owner == msg.sender, "Only owner can update listing price");
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function getLatestIdToListedToken() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    // This will return all the NFTs currently listed to be sold on the marketplace
    // function getAllNFTs() public view returns (ListedToken[] memory) {
    //     uint nftCount = _tokenIds.current();
    //     ListedToken[] memory tokens = new ListedToken[](nftCount);
    //     uint currentIndex = 0;
    //     uint currentId;

    //     for (uint i = 0; i < nftCount; i++) {
    //         currentId = i + 1;
    //         ListedToken storage currentItem = idToListedToken[currentId];
    //         tokens[currentIndex] = currentItem;
    //         currentIndex += 1;
    //     }
    //     return tokens;
    // }

    function getAllNFTs() public view returns (ListedToken[] memory) {
    uint nftCount = _tokenIds.current();
    uint listedCount = 0;
    uint currentId;

    // Count how many NFTs are currently listed
    for (uint i = 0; i < nftCount; i++) {
        if (idToListedToken[i + 1].currentlyListed) {
            listedCount += 1;
        }
    }

    // Create an array with only listed NFTs
    ListedToken[] memory tokens = new ListedToken[](listedCount);
    uint currentIndex = 0;

    for (uint i = 0; i < nftCount; i++) {
        currentId = i + 1;
        if (idToListedToken[currentId].currentlyListed) {
            tokens[currentIndex] = idToListedToken[currentId];
            currentIndex += 1;
        }
    }
    return tokens;
}


    // Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i + 1].owner == msg.sender || idToListedToken[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i + 1].owner == msg.sender || idToListedToken[i + 1].seller == msg.sender) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // The first time a token is created, it is listed here
    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        // Helper function to update Global variables and emit an event
        createListedToken(newTokenId, price);

        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        require(msg.value == listPrice, "Hopefully sending the correct price");
        require(price > 0, "Make sure the price isn't negative");

        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        _transfer(msg.sender, address(this), tokenId);
        emit TokenListedSuccess(tokenId, address(this), msg.sender, price, true);
    }


    function executeSale(uint256 tokenId) public payable {
    uint price = idToListedToken[tokenId].price;
    address seller = idToListedToken[tokenId].seller;
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    // Mark the token as no longer listed
    idToListedToken[tokenId].currentlyListed = false;
    idToListedToken[tokenId].seller = payable(msg.sender); // Update seller to new owner
    _itemsSold.increment();

    _transfer(address(this), msg.sender, tokenId);
    approve(address(this), tokenId);

    payable(owner).transfer(listPrice);
    payable(seller).transfer(msg.value);
}


    // Function to update the price of an NFT
    function updatePrice(uint256 tokenId, uint256 newPrice) public {
        ListedToken storage listedToken = idToListedToken[tokenId];
        require(msg.sender == listedToken.seller, "Only the seller can update the price");
        require(listedToken.currentlyListed, "This token is not currently listed for sale");
        require(newPrice > 0, "Price must be greater than zero");

        // Update the price in the mapping
        listedToken.price = newPrice;

        emit PriceUpdated(tokenId, newPrice); // Emit event for price update
    }

}
