// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

contract Alchemy is ERC1155,Ownable,ERC1155Burnable,ReentrancyGuard{
    
    using Counters for Counters.Counter;
    
    Counters.Counter private _storeListing;
    Counters.Counter private _soldItems;
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    struct packSale{
        uint256 size;
        address senderAddress;
    }

    struct sales{
        uint256 tokenId;
        uint256 price;
        uint256 quantity;
        address seller;
    }

    mapping(uint256=>ingredient[]) public RecipeBook;
    mapping(bytes32=>packSale) internal packSaleInfo;
    mapping(address=>uint256) public userBalance;

    //marketplace listing - uint to sale
    mapping(uint256=>sales) marketplaceListing;
    
    //user sales info - address to listing id array
    mapping(address=>uint256[]) userSalesList;
    
    //locked balance - address,token Id to locked amount
    mapping(address=>mapping(uint256=>uint256)) userLockedAmount;
    
    bytes32 internal keyHash;
    uint256 internal fee;
    
    address internal AlchemySalesAddress;

    event RecipeAdded(uint256 indexed targetId,ingredient[] indexed ingredients);
    event UserSignedUp(address indexed userAddress);
    event PackSale(address indexed userAddress,uint[] indexed cardsIdAdded);
    
    
    constructor() ERC1155("https://raw.githubusercontent.com/Project-Alchemists/Alchemy-Contracts/main/json-data/{id}.json") 
    {
    
    }
    
    function SetAlchemySalesAddress(address salesAddress) external onlyOwner {
        AlchemySalesAddress = salesAddress;
    }
    
    function InitiatePackSale(uint256 packSize) external payable returns(uint[] memory){
        require(msg.value == 0.01 ether + packSize*0.01 ether,"Alchemy: User needs to pay value");
        require(packSize < 3,"Alchemy: Pack size is not supported");
        userBalance[owner()] += msg.value;
        uint randomResult = vrf();
        uint256 size = 5+(packSize*5);
        uint[] memory cardArray = new uint[](size);
    
        for(uint i=0;i<size;i++){
            uint16 modulo = uint16(randomResult%100);
            randomResult = randomResult/100;
            cardArray[i] = modulo%6;
        }
        
        for(uint i=0;i<size;i++){
            _mint(msg.sender,cardArray[i],1,"");
        }
        emit PackSale(msg.sender,cardArray);
        return cardArray;
    } 
    
    function vrf() internal view returns (uint result) {
        uint[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
                }
        result := mload(memPtr)
        }
        result = uint(result);
    }
    
    
    function CraftCards(uint256 targetId) external {
        //do the crafting stuff here
        uint length = RecipeBook[targetId].length;
        require(length > 0,"Alchemy: Recipe doesn't exist");
        
        for(uint i = 0;i<length;i++){
            require(balanceOf(msg.sender,RecipeBook[targetId][i].id) >= 
            RecipeBook[targetId][i].quantity,"Alchemy: User doesn't have required ingredients");
        }
        
        for(uint i = 0;i<length;i++){
            burn(msg.sender,RecipeBook[targetId][i].id,RecipeBook[targetId][i].quantity);
        }
        
        _mint(msg.sender,targetId,1,"");
    }
    
    function AddRecipe(uint256 targetId,ingredient[] memory ingredients) external onlyOwner {
        //allow owner to add recipes
        for(uint256 i = 0;i<ingredients.length;i++){
            RecipeBook[targetId].push(ingredients[i]);
        }
        emit RecipeAdded(targetId,ingredients);
    }
    
    
    function SellOnMarket(uint256 tokenId,uint256 quantity,uint256 price) external{
        require(quantity > 0,"Alchemy: Need to sell at least 1 token");
        require(balanceOf(msg.sender,tokenId) - userLockedAmount[msg.sender][tokenId] >= quantity,"Alchemy: Not enough balance to sell");
        require(RecipeBook[tokenId].length > 0,"Alchemy: This token can't be sold");
        setApprovalForAll(AlchemySalesAddress,true);
        _storeListing.increment();
        uint256 listingId = _storeListing.current();
        marketplaceListing[listingId] = sales(
            tokenId,
            price,
            quantity,
            msg.sender
        );
        userSalesList[msg.sender].push(listingId);
        userLockedAmount[msg.sender][tokenId] += quantity;
    }
    
    function GetUserSalesList() external view returns(uint256[] memory){
        return userSalesList[msg.sender];
    }
    
    function GetMarketListingById(uint256 listingId) external view returns(sales memory){
        return marketplaceListing[listingId];
    }
    
    function GetStoreListingCount() external view returns(uint256){
        return  _storeListing.current() - _soldItems.current();
    }
    function GetAllMarketPlaceListings() external view returns(sales[] memory){
        uint256 length = _storeListing.current() - _soldItems.current();
        uint256 currentIndex = 0;
        sales[] memory allSales = new sales[](length);
        for(uint256 i=1;i<=_storeListing.current();i++){
            if(marketplaceListing[i].quantity > 0){
                allSales[currentIndex] = (marketplaceListing[i]);
                currentIndex++;
            }
        }
        return allSales;
    }
    
    function GetUserLockedBalance(uint256 tokenId) external view returns(uint256){
        return userLockedAmount[msg.sender][tokenId];
    }
    
    function RemoveListing(uint256 listingId) external{
        require(marketplaceListing[listingId].seller == msg.sender,"Alchemy: Only seller can remove listing");
        require(marketplaceListing[listingId].quantity > 0,"Alchemy: No tokens left to remove from listing");
        sales memory userListing = marketplaceListing[listingId];
        delete marketplaceListing[listingId];
        userLockedAmount[userListing.seller][userListing.tokenId] -= userListing.quantity;
        _soldItems.increment();
    }
    
    
    function ModifyListing(uint256 listingId,uint256 quantity,uint256 price) external{
        sales memory listing = marketplaceListing[listingId];
        
        require(listing.seller == msg.sender,"Alchemy: Only seller can modify listing");
        require(quantity != 0,"Alchemy: Consider using remove listing instead");
        require(price != 0,"Alchemy: You really want to sell it for free?");
        
        if(quantity > listing.quantity){
            uint extra = quantity - listing.quantity;
            require(balanceOf(msg.sender,listing.tokenId) >=
            (userLockedAmount[msg.sender][listing.tokenId]+extra),"Alchemy: Not enough balance to sell");
            userLockedAmount[listing.seller][listing.tokenId] += extra;
        }
        else if(quantity < listing.quantity){
            uint extra = listing.quantity - quantity;
            userLockedAmount[listing.seller][listing.tokenId] -= extra;
        }
        
        marketplaceListing[listingId] = sales(
            listing.tokenId,
            price,
            quantity,
            listing.seller
        );
        
    }
    
    function BuyFromMarket(uint256 listingId,address toAddress,uint256 quantity) external payable nonReentrant{
        require(marketplaceListing[listingId].quantity >= quantity,"Alchemy: Not enough tokens to purchase");
        require(quantity > 0,"Alchemy: Need to buy at least 1 token");
        require(msg.value >= quantity*marketplaceListing[listingId].price,"Alchemy: Not enough value paid");
        sales memory listing = marketplaceListing[listingId];
        safeTransferFrom(listing.seller,toAddress,listing.tokenId,quantity,"");
        userBalance[listing.seller] += msg.value;
        userLockedAmount[listing.seller][listing.tokenId] -= quantity;
        marketplaceListing[listingId].quantity -= quantity;
        if(marketplaceListing[listingId].quantity == 0){
            _soldItems.increment();
        }
    }
    
    function RetrieveFunds() external nonReentrant{
        require(userBalance[msg.sender] > 0,"Alchemy: No balance to retreive");
        uint256 balance = userBalance[msg.sender];
        payable(msg.sender).transfer(balance);
        userBalance[msg.sender] = 0;
    }
    
    
}

contract AlchemySales is Ownable{
    
    address internal AlchemyAddress;
    
    function SetAlchemyAddress(address AlcAddress) external onlyOwner{
        AlchemyAddress = AlcAddress;
    } 
    
    function PurchaseFromMarket(uint256 listingId,uint256 quantity) external payable{
        Alchemy A = Alchemy(AlchemyAddress);
        A.BuyFromMarket{value:msg.value}(listingId,msg.sender,quantity);
    }
}
