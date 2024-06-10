// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "./BaseTest.sol";

contract MinterSetEmission is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    TestOwner team;

    event EmissionSet(address indexed setter, uint256 emission);

    function setUp() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amountsVelo = new uint256[](2);
        amountsVelo[0] = 1e25;
        amountsVelo[1] = 1e25;
        mintFlow(owners, amountsVelo);
        team = new TestOwner();
        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(sky), address(artProxy));
        deployPairFactoryAndRouter();
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(
            address(escrow),
            address(factory),
            address(gaugeFactory),
            address(bribeFactory)
        );
        factory.setVoter(address(voter));
        deployPairWithOwner(address(owner));
        // deployOptionTokenWithOwner(address(owner), address(gaugeFactory));
        // // gaugeFactory.setOFlow(address(oFlow));
        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(sky);
        voter.initialize(tokens, address(owner));
        sky.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, TWENTY_SIX_WEEKS);
        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoter(address(voter));

        minter = new Minter(
            address(voter),
            address(escrow),
            address(distributor)
        );
        distributor.setDepositor(address(minter));
        sky.setMinter(address(minter));

        sky.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(
            address(FRAX),
            address(sky),
            false,
            TOKEN_1,
            TOKEN_1,
            0,
            0,
            address(owner),
            block.timestamp
        );

        address pair = router.pairFor(address(FRAX), address(sky), false);

        sky.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair, 0);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(sky.balanceOf(address(escrow)), TOKEN_1);

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);

        Minter.Claim[] memory claims = new Minter.Claim[](1);
        claims[0] = Minter.Claim({
            claimant: address(owner),
            amount: TOKEN_1M,
            lockTime: TWENTY_SIX_WEEKS
        });
        minter.initialMintAndLock(claims, 13 * TOKEN_1M);
        minter.startActivePeriod();

        assertEq(escrow.ownerOf(2), address(owner));
        assertEq(escrow.ownerOf(3), address(0));
        vm.roll(block.number + 1);
        assertEq(sky.balanceOf(address(minter)), 12 * TOKEN_1M);

        uint256 before = sky.balanceOf(address(owner));
        minter.update_period(); // initial period week 1
        uint256 after_ = sky.balanceOf(address(owner));
        assertEq(minter.weekly(), 13 * TOKEN_1M);
        assertEq(after_ - before, 0);
        vm.warp(block.timestamp + ONE_WEEK);
        vm.roll(block.number + 1);
        before = sky.balanceOf(address(owner));
        minter.update_period(); // initial period week 2
        after_ = sky.balanceOf(address(owner));
        assertEq(minter.weekly(), (13 * TOKEN_1M * 990) / 1000); // <13M for week shift
    }

    function testSetEmission() public {
        _elapseOneWeek();

        owner.setTeam(address(minter), address(team));
        team.acceptTeam(address(minter));

        // expect revert from owner3 setting emission
        vm.expectRevert(abi.encodePacked("not team"));
        owner3.setEmission(address(minter), 50);

        // expect revert for out-of-bounds emission
        vm.expectRevert(abi.encodePacked("emission out of range"));
        team.setEmission(address(minter), 1981);

        vm.expectRevert(abi.encodePacked("emission out of range"));
        team.setEmission(address(minter), 499);

        // new emission in bounds
        vm.expectEmit(true, true, false, true);
        emit EmissionSet(address(team), 500);
        team.setEmission(address(minter), 500);

        minter.update_period(); // new period
        assertEq(
            minter.weekly(),
            (((13 * TOKEN_1M * 990) / 1000) * 500) / 1000
        );
    }

    function _elapseOneWeek() private {
        vm.warp(block.timestamp + ONE_WEEK);
        vm.roll(block.number + 1);
    }
}
