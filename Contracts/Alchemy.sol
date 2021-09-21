// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract Alchemy is ERC1155,Ownable,ERC1155Burnable,VRFConsumerBase,ReentrancyGuard{
    
    uint public randomNum;
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    struct packSale{
        uint256 size;
        address senderAddress;
    }

    struct sales{
        uint256 price;
        uint256 quantity;
    }

    mapping(uint256=>ingredient[]) public RecipeBook;
    mapping(bytes32=>packSale) internal packSaleInfo;
    mapping(address=>uint256) public userBalance;
    
    //mapping user address to token id to sales info
    mapping(address=>mapping(uint256=>sales)) userSaleInfo;
    
    bytes32 internal keyHash;
    uint256 internal fee;
    
    address internal AlchemySalesAddress;

    event RecipeAdded(uint256 indexed targetId,ingredient[] indexed ingredients);
    event UserSignedUp(address indexed userAddress);
    event PackSale(address indexed userAddress,uint[] indexed cardsIdAdded);
    
    
    constructor() ERC1155("https://game.example/api/item/{id}.json") 
    VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,0x326C977E6efc84E512bB9C30f76E30c160eD06FB) {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18; 
    }
    
    function SetAlchemySalesAddress(address salesAddress) external onlyOwner {
        AlchemySalesAddress = salesAddress;
    }
    
    function InitiatePackSale(uint256 packSize) external payable returns(bytes32){
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        require(msg.value == 0.01 ether + packSize*0.01 ether,"Alchemy: User needs to pay value");
        require(packSize < 3,"Alchemy: Pack size is not supported");
        userBalance[owner()] += msg.value;
        bytes32 requestId = requestRandomness(keyHash,fee);
        packSaleInfo[requestId].size = packSize;
        packSaleInfo[requestId].senderAddress = msg.sender;
        return requestId;
    } 
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomNum = randomness;
        uint256 randomResult = randomness;
        uint256 size = 5+(packSaleInfo[requestId].size*5);
        address sender = packSaleInfo[requestId].senderAddress;
        
        delete packSaleInfo[requestId];
        uint[] memory cardArray = new uint[](size);
    
        for(uint i=0;i<size;i++){
            uint16 modulo = uint16(randomResult%100);
            randomResult = randomResult/100;
            cardArray[i] = modulo%6;
        }
        
        for(uint i=0;i<size;i++){
            _mint(sender,cardArray[i],1,"");
        }
        emit PackSale(sender,cardArray);
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
        require(userSaleInfo[msg.sender][tokenId].quantity == 0,"Alchemy: Tokens already on sale, use modify instead");
        require(quantity > 0,"Alchemy: Need to sell at least 1 token");
        require(balanceOf(msg.sender,tokenId) >= quantity,"Alchemy: Not enough balance to sell");
        setApprovalForAll(AlchemySalesAddress,true);
        userSaleInfo[msg.sender][tokenId].quantity = quantity;
        userSaleInfo[msg.sender][tokenId].price = price;
    }
    
    function ModifySalesInfo(uint256 tokenId,uint256 quantity,uint256 price) external{
        require(userSaleInfo[msg.sender][tokenId].quantity > 0,"Alchemy: Tokens are not on sale, use SellOnMarket instead");
        require(balanceOf(msg.sender,tokenId) >= quantity,"Alchemy: Not enough balance to sell");
        userSaleInfo[msg.sender][tokenId].quantity = quantity;
        userSaleInfo[msg.sender][tokenId].price = price;
    }
    
    function BuyFromMarket(uint256 tokenId,address fromAddress,address toAddress,uint256 quantity) external payable{
        require(userSaleInfo[fromAddress][tokenId].quantity > quantity,"Alchemy: Not enough tokens to purchase");
        require(quantity > 0,"Alchemy: Need to buy at least 1 token");
        require(msg.value >= quantity*userSaleInfo[fromAddress][tokenId].price,"Alchemy: Not enough value paid");
        safeTransferFrom(fromAddress,toAddress,tokenId,quantity,"");
        userBalance[fromAddress] += msg.value;
        userSaleInfo[fromAddress][tokenId].quantity -= quantity;
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
    
    function PurchaseFromMarket(uint256 tokenId,address fromAddress,uint256 quantity) external payable{
        Alchemy A = Alchemy(AlchemyAddress);
        A.BuyFromMarket{value:msg.value}(tokenId,fromAddress,msg.sender,quantity);
    }
}