// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
contract Alchemy is ERC1155,Ownable,ERC1155Burnable{
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    mapping(uint256=>ingredient[]) public RecipeBook;
    
    event RecipeAdded(uint256 indexed targetId,ingredient[] indexed ingredients);
    
    constructor() ERC1155("https://game.example/api/item/{id}.json") {
        
    }
    
    function BuyPack(uint256 packSize,uint256 randomSeed) public {
        //mint pack based on a random seed and pack size
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
}