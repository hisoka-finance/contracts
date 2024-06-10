// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "./BaseTest.sol";

contract VotingEscrowTest is BaseTest {
    VotingEscrow escrow;

    function setUp() public {
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e21;
        mintFlow(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(sky), address(artProxy));
    }

    function testCreateLock() public {
        sky.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // Balance should be zero before and 1 after creating the lock
        assertEq(escrow.balanceOf(address(owner)), 0);
        escrow.create_lock(1e21, lockDuration);
        assertEq(escrow.currentTokenId(), 1);
        assertEq(escrow.ownerOf(1), address(owner));
        assertEq(escrow.balanceOf(address(owner)), 1);
    }

    function testSplit() public {
        sky.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 3e20;
        amounts[1] = 7e20;

        int amount;
        uint duration;
        (amount, duration) = escrow.locked(1);
        assertEq(amount, 1e21);
        assertEq(duration, lockDuration);
        assertEq(escrow.ownerOf(1), address(owner));
        assertEq(escrow.balanceOf(address(owner)), 1);

        escrow.split(amounts, 1);

        (amount, duration) = escrow.locked(1);
        assertEq(amount, 0);
        assertEq(duration, 0);
        assertEq(escrow.ownerOf(1), address(0));

        (amount, duration) = escrow.locked(2);
        assertEq(amount, 3e20);
        assertEq(duration, lockDuration);
        assertEq(escrow.ownerOf(2), address(owner));

        (amount, duration) = escrow.locked(3);
        assertEq(amount, 7e20);
        assertEq(duration, lockDuration);
        assertEq(escrow.ownerOf(3), address(owner));

        assertEq(escrow.balanceOf(address(owner)), 2);
    }

    function testCreateLockOutsideAllowedZones() public {
        sky.approve(address(escrow), 1e21);
        vm.expectRevert(abi.encodePacked("Voting lock can be 26 weeks max"));
        escrow.create_lock(1e21, TWENTY_SIX_WEEKS + ONE_WEEK);
    }

    function testWithdraw() public {
        sky.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        // Try withdraw early
        uint256 tokenId = 1;
        vm.expectRevert(abi.encodePacked("The lock didn't expire"));
        escrow.withdraw(tokenId);
        // Now try withdraw after the time has expired
        vm.warp(block.timestamp + lockDuration);
        vm.roll(block.number + 1); // mine the next block
        escrow.withdraw(tokenId);

        assertEq(sky.balanceOf(address(owner)), 1e21);
        // Check that the NFT is burnt
        assertEq(escrow.balanceOfNFT(tokenId), 0);
        assertEq(escrow.ownerOf(tokenId), address(0));
    }

    function testCheckTokenURICalls() public {
        // tokenURI should not work for non-existent token ids
        vm.expectRevert(abi.encodePacked("Query for nonexistent token"));
        escrow.tokenURI(999);
        sky.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        uint256 tokenId = 1;
        vm.warp(block.timestamp + lockDuration);
        vm.roll(block.number + 1); // mine the next block

        // Just check that this doesn't revert
        escrow.tokenURI(tokenId);

        // Withdraw, which destroys the NFT
        escrow.withdraw(tokenId);

        // tokenURI should not work for this anymore as the NFT is burnt
        vm.expectRevert(abi.encodePacked("Query for nonexistent token"));
        escrow.tokenURI(tokenId);
    }

    function testConfirmSupportsInterfaceWorksWithAssertedInterfaces() public {
        // Check that it supports all the asserted interfaces.
        bytes4 ERC165_INTERFACE_ID = 0x01ffc9a7;
        bytes4 ERC721_INTERFACE_ID = 0x80ac58cd;
        bytes4 ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

        assertTrue(escrow.supportsInterface(ERC165_INTERFACE_ID));
        assertTrue(escrow.supportsInterface(ERC721_INTERFACE_ID));
        assertTrue(escrow.supportsInterface(ERC721_METADATA_INTERFACE_ID));
    }

    function testCheckSupportsInterfaceHandlesUnsupportedInterfacesCorrectly()
        public
    {
        bytes4 ERC721_FAKE = 0x780e9d61;
        assertFalse(escrow.supportsInterface(ERC721_FAKE));
    }
}
