// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Alchemy is ERC1155,Ownable{
    
    mapping(uint256=>uint256[]) public RecipeBook;
    
    event RecipeAdded(uint256 indexed targetId,uint256[] indexed ingredients);
    
    constructor() ERC1155("https://game.example/api/item/{id}.json") {
        
    }
    
    function BuyPack(uint256 packSize,uint256 randomSeed) public {
        //mint pack based on a random seed and pack size
    } 
    
    function CraftCards() external {
        //do the crafting stuff here
    }
    
    function AddRecipe(uint256 targetId, uint256[] memory ingredients) external onlyOwner {
        //allow owner to add recipes
    } 
}