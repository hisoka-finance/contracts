// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import "contracts/factories/PairFactory.sol";
import "contracts/Router.sol";
import "contracts/Pair.sol";
import "contracts/interfaces/IERC20.sol";
import "contracts/interfaces/IWETH.sol";

contract FeeTester is Script {
    PairFactory factory =
        PairFactory(0x2516212168034b18a0155FfbE59f2f0063fFfBD9);
    Router router = Router(payable(0xAA111C62cDEEf205f70E6722D1E22274274ec12F));
    Pair pair = Pair(0x1d675222304d1c09370A3922F46B63d6024ea768);
    address user = 0x25aB3Efd52e6470681CE037cD546Dc60726948D3;
    IERC20 usdc = IERC20(0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4);
    IERC20 weth = IERC20(0x5300000000000000000000000000000000000004);

    uint amount0Out = 100;
    uint amount1Out = 640081084;

    address tokenA;
    address tokenB;
    bool stable;
    uint amountADesired = 1000000;
    uint amountBDesired = 640081085819897;
    uint amountAMin = 950000;
    uint amountBMin1 = 608077031528902;
    //address to;
    uint deadline = 1697860573;

    uint256 liquidity = 1 ether;

    function run() public {
        vm.startBroadcast();

        // uint amountIn=1 ether;
        // uint amountOutMin=1 ether;
        // address tokenFrom=address(usdc);
        // address tokenTo=address(weth);
        // bool stable=false;
        address to = 0x25aB3Efd52e6470681CE037cD546Dc60726948D3;
        // uint deadline;
        // amountADesired =
        //     usdc.balanceOf(0x6B7d1c9d519DFc3A5D8D1B7c15d4E5bbe8DdE1cF) /
        //     2;

        usdc.approve(address(router), amountADesired);
        //console2.log(weth.balanceOf(address(user)));
        IWETH(address(weth)).deposit{value: amountBDesired}();
        //console2.log(weth.balanceOf(address(user)));
        weth.approve(address(router), amountBDesired);
        // console2.log(
        //     weth.allowance(
        //         0x25aB3Efd52e6470681CE037cD546Dc60726948D3,
        //         address(router)
        //     )
        // );

        uint256 usdcBalance = usdc.balanceOf(user);
        uint256 wethBalance = weth.balanceOf(user);
        console2.log(usdcBalance);
        console2.log(wethBalance);
        router.addLiquidity(
            address(usdc),
            address(weth),
            false,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin1,
            user,
            deadline
        );
        //swapExactTokensForTokensSimple
        //pair.swap(amount0Out, amount1Out, to, new bytes(0));
        //pair.swap(amount0Out, amount1Out, to, new bytes(0));
        uint[] memory amountsWETH = new uint[](1);

        amountsWETH = router.swapExactTokensForTokensSimple(
            amount0Out,
            amount1Out,
            address(usdc),
            address(weth),
            false,
            to,
            deadline
        );
        uint[] memory amountsUSDC = new uint[](1);
        amountsUSDC = router.swapExactTokensForTokensSimple(
            amountsWETH[0],
            amount0Out,
            address(weth),
            address(usdc),
            false,
            to,
            deadline
        );
        console2.log(amountsUSDC[0]);
        console2.log(amountsWETH[0]);
        // router.removeLiquidity(
        //     address(usdc),
        //     address(weth),
        //     false,
        //     liquidity,
        //     amountAMin,
        //     amountBMin1,
        //     user,
        //     deadline
        // );

        uint256 usdcBalanceAfter = usdc.balanceOf(user);
        uint256 wethBalanceAfter = weth.balanceOf(user);
        console2.log(usdcBalanceAfter);
        console2.log(wethBalanceAfter);

        // router.addLiquidity();
        // router.swapExactTokensForTokensSimple(amountIn,amountOutMin,usdc,weth,stable,to,deadline);
        // router.swapExactTokensForTokensSimple(amountIn,amountOutMin,weth,usdc,stable,to,deadline);
        // router.removeLiquidity();

        // console.log();

        vm.stopBroadcast();
    }
}
// without broadcast simulates on anvil without publishing
// forge script script/FeeTester.s.sol:FeeTester --rpc-url http://localhost:8545

//usdc holder
//cast send 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4 --unlocked --from $user "transferFrom(address,uint256)(bool)" "0x25aB3Efd52e6470681CE037cD546Dc60726948D3" $user "200000000000" --legacy

//export user=0x25aB3Efd52e6470681CE037cD546Dc60726948D3
//cast rpc anvil_impersonateAccount $user

//forge script --sender 0x25aB3Efd52e6470681CE037cD546Dc60726948D3 --unlocked script/FeeTester.s.sol:FeeTester --rpc-url http://localhost:8545 --legacy
