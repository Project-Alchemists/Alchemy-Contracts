// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
contract Alchemy is ERC1155,Ownable,ERC1155Burnable,VRFConsumerBase{
    
    uint public randomNum;
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    struct packSale{
        uint256 size;
        address senderAddress;
    }
    
    struct requirement{
        uint256 quantity;
        uint256 price;
    }
    

    mapping(uint256=>ingredient[]) public RecipeBook;
    mapping(bytes32=>packSale) internal packSaleInfo;
    mapping(address=>uint256) public userBalance;
    
    //double mapping address to id to quantity,price 
    mapping(address=>mapping(uint256=>requirement)) internal buyerInfo;
    mapping(address=>mapping(uint256=>requirement)) internal sellerInfo;
    
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
    
    function EnableSales() external {
        setApprovalForAll(AlchemySalesAddress,true);
    }
    
    function DisableSales() external{
        for(uint i=0;i<10;i++)
        {
            delete sellerInfo[msg.sender][i];
            
        }
        setApprovalForAll(AlchemySalesAddress,false);
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
    
    
    function PutBuyRequest(uint256 id,uint256 quantity) external payable{
        uint length = RecipeBook[id].length;
        require(length > 0,"Alchemy: Target item can't be bought in marketplace");
        requirement memory buyerRequirement;
        buyerRequirement.quantity = quantity;
        buyerRequirement.price = msg.value;
        buyerInfo[msg.sender][id].quantity += quantity;
        buyerInfo[msg.sender][id].price += msg.value;
    }
    
    // function ModifyBuyRequest(uint256[] id,uint256[] quantity){
    //     idLength = id.length;
    //     quantityLength = quantity.length;
    //     require(idLength == quantityLength,"Alchemy: Array lengths don't match");
    //     for(uint i =0;i<idLength;i++){
    //         uint length = RecipeBook[id[i]].length;
    //         require(length > 0,"Alchemy: Target item can't be bought in marketplace");
    //     }
    //     for(uint i=0;i<idLength;i++){
    //         ui
    //     }
        
    // }
    function RemoveBuyRequest(uint256 requestId) external {
        require(buyerInfo[msg.sender][requestId].quantity > 0,"Alchemy: Invalid requestId");
        uint256 amount = buyerInfo[msg.sender][requestId].price;
        delete buyerInfo[msg.sender][requestId];
        payable(msg.sender).transfer(amount);
    }
    
    function PutSaleRequest(uint256 id,uint256 quantity,uint256 price) external{
        require(isApprovedForAll(msg.sender,AlchemySalesAddress),"Alchemy: Sales haven't been enabled but sender");
        require(balanceOf(msg.sender,id) > quantity,"Alchemy: Sender doesn't have enough token balance");
        sellerInfo[msg.sender][id].quantity = quantity;
        sellerInfo[msg.sender][id].price = price;
    }
    
    function RetrieveFunds() external {
        uint256 balance = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
    
    // function PrizeRetrieve() external{
    //     //check if user has the top NFT, if yes burn that and give user a prize amount
        
    // }
}

// contract AlchemySales is Ownable{
    
//     address internal AlchemyAddress;
    
//     function SetAlchemyAddress(address AlcAddress) external onlyOwner{
//         AlchemyAddress = AlcAddress;
//     } 
    
//     function PurchaseFromMarket() external payable{
//         Alchemy A = Alchemy(AlchemyAddress);
//     }
// }