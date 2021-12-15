// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

contract Alchemy is ERC1155,Ownable,ERC1155Burnable,ReentrancyGuard{
    
    using Counters for Counters.Counter;
    
    struct ingredient{
        uint256 id;
        uint256 quantity;
    }
    
    mapping(uint256=>ingredient[]) public RecipeBook;
    mapping(address=>uint256) public userBalance;

    event RecipeAdded(uint256 indexed targetId,ingredient[] indexed ingredients);
    event PackSale(address indexed userAddress,uint token);
        
    constructor() ERC1155("https://github.com/Project-Alchemists/Alchemy-Contracts/blob/main/json-data/{id}.json") 
    {
    
    }
    
    function InitiatePackSale(uint256 token) external payable returns(uint){
        require(msg.value == 0.01 ether,"Alchemy: User needs to pay value");
        userBalance[owner()] += msg.value;
        _mint(msg.sender,token,1,"");
        emit PackSale(msg.sender,token);
        return token;
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
    
    function RetrieveFunds() external nonReentrant{
        require(userBalance[msg.sender] > 0,"Alchemy: No balance to retreive");
        uint256 balance = userBalance[msg.sender];
        payable(msg.sender).transfer(balance);
        userBalance[msg.sender] = 0;
    }
    
    
}
