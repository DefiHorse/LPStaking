// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IPancakeRouter.sol";

interface IPancakePair {
    function totalSupply() external view returns (uint);
}

contract DfhPrice {
    // @notice this block config for testnet & using pancake token
    address private pcsRouter = 0xCc7aDc94F3D80127849D2b41b6439b7CF1eB4Ae0;
    address private bnbContract = 0x0dE8FCAE8421fc79B29adE9ffF97854a424Cad09;
    address private busdContract = 0xE0dFffc2E01A7f051069649aD4eb3F518430B6a4;
    address private tokenContract = 0xFC15F942F73039EA377C4da9d41FDA32E56E5aa4;

    // @notice this block config for mainnet
//    address private pcsRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
//    address private bnbContract = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
//    address private busdContract = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
//    address private tokenContract = 0x5fdAb5BDbad5277B383B3482D085f4bFef68828C;

    function _getBnbPrice () 
        internal
        view
        returns (uint256)
    {
        address[] memory path;
        path  = new address[](2);
        path[0] = bnbContract;
        path[1] = busdContract;
        uint256[] memory _oneBNBWithBusdArr = IPancakeRouter01(pcsRouter).getAmountsOut(1*(10**18), path);

        return _oneBNBWithBusdArr[1];
    }

    function _getCurPrice(address _tokenContract)
        internal
        view
        returns (uint256)
    {
        address[] memory path;
        path  = new address[](2);
        path[0] = _tokenContract;
        path[1] = bnbContract;
        uint256[] memory _oneTokenWithBNBArr = IPancakeRouter01(pcsRouter).getAmountsOut(1*(10**18), path);

        uint256 _oneTokenWithBNB = _oneTokenWithBNBArr[1];
        uint256 _oneBNBWithBusd = _getBnbPrice();

        return _oneTokenWithBNB * _oneBNBWithBusd;
    }

    function _calcReturnedValue(address lpToken)
        internal 
        view 
        returns(uint256, uint256, uint256)
    {
        uint256 _curPriceToken = _getCurPrice(tokenContract);

        uint256 amountToken =  IERC20(tokenContract).balanceOf(lpToken);

        uint256 amountBNB =  IERC20(bnbContract).balanceOf(lpToken);
        uint256 bnbPrice = _getBnbPrice();
        uint256 _totalValueofLP = (amountBNB * bnbPrice) + (amountToken * _curPriceToken);
        uint256 _totalSupplyofLP = IPancakePair(lpToken).totalSupply();
        return (_totalValueofLP,_totalSupplyofLP,_curPriceToken);
    }
}
