// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_ ) ERC20(name_, symbol_) {
        _mint(msg.sender, 100_000_000 ether);
    }

    function sendTokens(address _add, uint256 _amount) public {
        _mint(_add, _amount);
    }
}
