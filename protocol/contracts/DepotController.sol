pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import {Oracle} from "./oracle/Oracle.sol";
import "./Constants.sol";
import "./interfaces/IUniswap.sol";
import "./interfaces/IERC20.sol";

contract DepotControl is Constants, Ownable, Oracle, ReentrancyGuard {

    using SafeMath for uint256;

    IUniswapV2Router01 public router;
    
    // Uniswap Router Address
    address constant ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant DEOX_ADDRESS = 0x000000000000000000000000000000000000dEaD; // This is just the test deox token address
    address constant DEA_ADDRESS = 0x02b7a1AF1e9c7364Dd92CdC3b09340Aea6403934; // This is just the test DEA token address
    address constant USDC_ADDRESS = 0x7d66CDe53cc0A169cAE32712fC48934e610aeF14; // This is just the test USDC token address

    constructor () public {

        router = IUniswapV2Router01(ROUTER_ADDRESS);
    }

    function fundController(uint256 _deoxAmount) public {
        
        address[] memory path1 = new address[](2);
        path1[0] = address(DEOX_ADDRESS);
        path1[1] = address(DEA_ADDRESS);

        IERC20(DEOX_ADDRESS).approve(address(router), _deoxAmount.div(20));

        // 5% of the totalRebaseDeox amount to buyback DEA
        uint[] memory deaAmounts = router.swapExactTokensForTokens(_deoxAmount.div(20), 0, path1, address(this), block.timestamp);
        uint256 deaAmountOut = deaAmounts[deaAmounts.length - 1];

        address[] memory path2 = new address[](2);
        path2[0] = address(DEOX_ADDRESS);
        path2[1] = address(USDC_ADDRESS);

        IERC20(DEOX_ADDRESS).approve(address(router), _deoxAmount.div(20));

        // 5% of the totalRebaseDeox amount to buyback USDC
        uint[] memory usdcAmounts = router.swapExactTokensForTokens(_deoxAmount.div(20), 0, path2, address(this), block.timestamp);
        uint256 usdcAmountOut = usdcAmounts[usdcAmounts.length - 1];
    }
}
