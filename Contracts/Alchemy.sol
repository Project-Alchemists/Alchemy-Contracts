// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/VRFConsumerBase.sol";
contract Alchemy is ERC1155,Ownable,ERC1155Burnable,VRFConsumerBase{
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    struct packSale{
        uint256 size;
        address senderAddress;
    }
    
    mapping(uint256=>ingredient[]) public RecipeBook;
    mapping(address=>bool) public userSignUp;
    mapping(bytes32=>packSale) internal packSaleInfo;
    
    bytes32 internal keyHash;
    uint256 internal fee;
    
    event RecipeAdded(uint256 indexed targetId,ingredient[] indexed ingredients);
    event UserSignedUp(address indexed userAddress);
    
    constructor() ERC1155("https://game.example/api/item/{id}.json") 
    VRFConsumerBase(0x8C7382F9D8f56b33781fE506E897a4F1e2d17255,0x326C977E6efc84E512bB9C30f76E30c160eD06FB) {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18; 
    }
    
    function InitiatePackSale(uint256 packSize) external payable returns(bytes32){
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        bytes32 requestId = requestRandomness(keyHash,fee);
        packSaleInfo[requestId].size = packSize;
        packSaleInfo[requestId].senderAddress = msg.sender;
        return requestId;
    } 
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 randomResult = randomness;
        uint256 size = packSaleInfo[requestId].size;
        address sender = packSaleInfo[requestId].senderAddress;
        
        //_mintBatch(sender,tokenIds,mintQuantity,"");
        
        //add logic to mint based on random numbers (_mintBatch)
        delete packSaleInfo[requestId];
        
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
    
    function SignUp() external payable{
        require(!userSignUp[msg.sender],"Alchemy: User is already signed up");
        require(msg.value == 0.5 ether,"Alchemy: User needs to send 0.5 Eth to sign up");
        userSignUp[msg.sender] = true;
    }
    
    function SignIn() external view returns(bool){
        return userSignUp[msg.sender];
    }
    
    function Sales() external payable{
        //sales logic
    }
    function PrizeRetrieve() external{
        //check if user has the top NFT, if yes burn that and give user a prize amount
    }
}