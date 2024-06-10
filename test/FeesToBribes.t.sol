// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "./BaseTest.sol";

contract FeesToBribesTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    ExternalBribe xbribe;

    function setUp() public {
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        mintFlow(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(sky), address(artProxy));

        deployPairFactoryAndRouter();
        deployVoter();
        factory.setFee(true, 2); // 2 bps = 0.02%
        deployPairWithOwner(address(owner));
        mintPairFraxUsdcWithOwner(address(owner));
    }

    function deployVoter() public {
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();

        voter = new Voter(
            address(escrow),
            address(factory),
            address(gaugeFactory),
            address(bribeFactory)
        );

        escrow.setVoter(address(voter));
        factory.setVoter(address(voter));
        deployPairWithOwner(address(owner));
        // deployOptionTokenWithOwner(address(owner), address(gaugeFactory));
        // // gaugeFactory.setOFlow(address(oFlow));
    }

    function testSwapAndFeesSentToTankWithoutGauge() public {
        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(USDC), address(FRAX), true);

        Router.route[] memory routeBack = new Router.route[](1);
        routeBack[0] = Router.route(address(FRAX), address(USDC), true);

        assertEq(
            router.getAmountsOut(USDC_1, routes)[1],
            pair.getAmountOut(USDC_1, address(USDC))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(USDC_1, routes);
        USDC.approve(address(router), USDC_1);
        console2.log(USDC.balanceOf(address(pair)));
        console2.log(FRAX.balanceOf(address(pair)));
        router.swapExactTokensForTokens(
            USDC_1,
            assertedOutput[1],
            routes,
            address(this),
            block.timestamp
        );
        console2.log(USDC.balanceOf(address(pair)));
        console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        uint256[] memory assertedOutputBack = router.getAmountsOut(
            982024667941568835,
            routeBack
        );

        vm.warp(block.timestamp + 1801);
        vm.roll(block.number + 1);
        FRAX.approve(address(router), 982024667941568835);
        router.swapExactTokensForTokens(
            982024667941568835,
            assertedOutputBack[1],
            routeBack,
            address(this),
            block.timestamp
        );
        console2.log(USDC.balanceOf(address(pair)));
        console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        uint256 lpBal = pair.balanceOf(address(this));
        //console2.log(pair.totalSupply());
        //console2.log(lpBal);
        pair.approve(address(router), lpBal);
        uint256 USDCbalanaceBefore = USDC.balanceOf(address(this));
        uint256 FRAXbalanaceBefore = FRAX.balanceOf(address(this));
        router.removeLiquidity(
            address(USDC),
            address(FRAX),
            true,
            lpBal,
            0,
            0,
            address(this),
            block.timestamp
        );
        uint256 USDCbalanaceAfter = USDC.balanceOf(address(this));
        uint256 FRAXbalanaceAfter = FRAX.balanceOf(address(this));
        // console2.log(USDC.balanceOf(address(pair)));
        // console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        console2.log(USDCbalanaceAfter - USDCbalanaceBefore);
        console2.log(FRAXbalanaceAfter - FRAXbalanaceBefore);

        console2.log(USDC.balanceOf(address(pair)));
        console2.log(FRAX.balanceOf(address(pair)));
    }

    function testFees() public {
        // Router.route[] memory routes = new Router.route[](1);
        // routes[0] = Router.route(address(USDC), address(FRAX), true);

        // Router.route[] memory routeBack = new Router.route[](1);
        // routeBack[0] = Router.route(address(FRAX), address(USDC), true);

        // assertEq(
        //     router.getAmountsOut(USDC_1, routes)[1],
        //     pair.getAmountOut(USDC_1, address(USDC))
        // );

        // uint256[] memory assertedOutput = router.getAmountsOut(USDC_1, routes);
        // USDC.approve(address(router), USDC_1);
        console2.log(USDC.balanceOf(address(pair)));
        console2.log(FRAX.balanceOf(address(pair)));
        // router.swapExactTokensForTokens(
        //     USDC_1,
        //     assertedOutput[1],
        //     routes,
        //     address(this),
        //     block.timestamp
        // );
        // console2.log(USDC.balanceOf(address(pair)));
        // console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        // uint256[] memory assertedOutputBack = router.getAmountsOut(
        //     982024667941568835,
        //     routeBack
        // );

        // vm.warp(block.timestamp + 1801);
        // vm.roll(block.number + 1);
        // FRAX.approve(address(router), 982024667941568835);
        // router.swapExactTokensForTokens(
        //     982024667941568835,
        //     assertedOutputBack[1],
        //     routeBack,
        //     address(this),
        //     block.timestamp
        // );
        // console2.log(USDC.balanceOf(address(pair)));
        // console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        uint256 lpBal = pair.balanceOf(address(owner));
        //console2.log(pair.totalSupply());
        //console2.log(lpBal);
        pair.approve(address(router), lpBal);
        uint256 USDCbalanaceBefore = USDC.balanceOf(address(owner));
        uint256 FRAXbalanaceBefore = FRAX.balanceOf(address(owner));
        console2.log(USDCbalanaceBefore);
        console2.log(FRAXbalanaceBefore);

        router.removeLiquidity(
            address(USDC),
            address(FRAX),
            true,
            lpBal,
            0,
            0,
            address(owner),
            block.timestamp
        );
        uint256 USDCbalanaceAfter = USDC.balanceOf(address(owner));
        uint256 FRAXbalanaceAfter = FRAX.balanceOf(address(owner));
        console2.log(USDCbalanaceAfter);
        console2.log(FRAXbalanaceAfter);
        // console2.log(USDC.balanceOf(address(pair)));
        // console2.log(FRAX.balanceOf(address(pair))); // 982024667941568835 frax received
        // console2.log(USDCbalanaceAfter - USDCbalanaceBefore);
        console2.log(FRAXbalanaceAfter - FRAXbalanaceBefore);

        // console2.log(USDC.balanceOf(address(pair)));
        // console2.log(FRAX.balanceOf(address(pair)));
    }

    // function testNonPairFactoryOwnerCannotSetTank() public {
    //     vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
    //     owner2.setTank(address(factory), address(owner));
    // }

    // function testPairFactoryOwnerCanSetTank() public {
    //     owner.setTank(address(factory), address(owner2));
    //     assertEq(factory.tank(), address(owner2));
    // }

    function testNonPairFactoryOwnerCannotChangeFees() public {
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        owner2.setFee(address(factory), true, 2);
    }

    function testPairFactoryOwnerCannotSetFeeAboveMax() public {
        vm.expectRevert(abi.encodePacked("fee too high"));
        factory.setFee(true, 501);
    }

    function testPairFactoryOwnerCanChangeFeesAndClaim() public {
        factory.setFee(true, 3); // 3 bps = 0.03%

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(USDC), address(FRAX), true);

        assertEq(
            router.getAmountsOut(USDC_1, routes)[1],
            pair.getAmountOut(USDC_1, address(USDC))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(USDC_1, routes);
        USDC.approve(address(router), USDC_1);
        router.swapExactTokensForTokens(
            USDC_1,
            assertedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );
        vm.warp(block.timestamp + 1801);
        vm.roll(block.number + 1);
        address tank = pair.tank();
        assertEq(USDC.balanceOf(tank), 0); // 0.01% -> 0.02%
    }

    function testNonPairFactoryOwnerCannotSetFeesOverrides() public {
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        vm.startPrank(address(owner2));
        factory.setFeesOverrides(address(pair), 21);
        vm.stopPrank();
    }

    function testPairFactoryOwnerCannotSetFeesOverridesAboveMax() public {
        vm.expectRevert(abi.encodePacked("fee too high"));
        factory.setFeesOverrides(address(pair), 501);
    }

    function testPairFactoryOwnerCanSetFeesOverridesAndClaim() public {
        factory.setFeesOverrides(address(pair), 30); // 30 bps = 0.3%

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(USDC), address(FRAX), true);

        assertEq(
            router.getAmountsOut(USDC_1, routes)[1],
            pair.getAmountOut(USDC_1, address(USDC))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(USDC_1, routes);
        USDC.approve(address(router), USDC_1);
        router.swapExactTokensForTokens(
            USDC_1,
            assertedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );
        vm.warp(block.timestamp + 1801);
        vm.roll(block.number + 1);
        address tank = pair.tank();
        assertEq(USDC.balanceOf(tank), 0);
    }

    function createLock() public {
        sky.approve(address(escrow), 5e17);
        escrow.create_lock(5e17, TWENTY_SIX_WEEKS);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 495063075414519385);
        assertEq(sky.balanceOf(address(escrow)), 5e17);
    }

    function testSwapAndClaimFees() public {
        createLock();
        vm.warp(block.timestamp + 1 weeks);

        voter.createGauge(address(pair), 0);
        address gaugeAddress = voter.gauges(address(pair));
        address xBribeAddress = voter.external_bribes(gaugeAddress);
        xbribe = ExternalBribe(xBribeAddress);

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(USDC), address(FRAX), true);

        assertEq(
            router.getAmountsOut(USDC_1, routes)[1],
            pair.getAmountOut(USDC_1, address(USDC))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(USDC_1, routes);
        USDC.approve(address(router), USDC_1);
        router.swapExactTokensForTokens(
            USDC_1,
            assertedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );

        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);

        vm.warp(block.timestamp + 1 weeks);

        assertEq(USDC.balanceOf(address(xbribe)), 200); // 0.01% -> 0.02%
        uint256 b = USDC.balanceOf(address(owner));
        address[] memory rewards = new address[](1);
        rewards[0] = address(USDC);
        console2.log(USDC.balanceOf(address(this)));
        xbribe.getReward(1, rewards);
        console2.log(USDC.balanceOf(address(this)));
        assertGt(USDC.balanceOf(address(owner)), b);
    }
}
