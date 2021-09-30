# Alchemy-Harmony

## Features
1. User can mint any 1 of 3 available pack sizes
2. Cards are minted randomly using Harmony VRF
3. User can burn those cards to craft next Gen rarer cards<br><br><b>
(Incomplete Features)</b>
4. User can place sell order of his non-base cards
5. Other users can then buy that card and craft even rarer card


## Functions

`function InitiatePackSale(uint256 packSize) external payable returns(uint[] memory)`
<br>- Randomly mint base cards for the user in packs for 5,10 and 15 using Harmony VRF.
<br   >
 `function CraftCards(uint256 targetId) external `
<br>- Mint target card after burning recipe cards
<br   >
`function AddRecipe(uint256 targetId,ingredient[] memory ingredients) external onlyOwner`
<br>- Owner can add recipe for cards
<br   >
`function SellOnMarket(uint256 tokenId,uint256 quantity,uint256 price) external`
<br>- Add store listing for your cards
<br   >
`function GetAllMarketPlaceListings() external view returns(sales[] memory)`
<br>- Get all MarketPlace listings
<br   >
_______________________________________________________________________________________________________

## Deployed Contract
Contract has been deployed on Harmony Testnet.<br>
Contract Address - 0xDe5D570712BA458cA9510d18ed8ca925A7C8F809

