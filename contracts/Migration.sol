// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract Migration {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    address private owner;

    constructor() {
        owner = msg.sender;
    }

    IERC20Upgradeable oldToken = IERC20Upgradeable(0x7c01268fF1797daA31ed155D72d86723e8a499e7);
    IERC20Upgradeable newToken = IERC20Upgradeable(0x2f381EFB2d7997bD3F2C779034bD7e922faDE971);

    function migrate(uint amount) public {

        require(
            oldToken.balanceOf(msg.sender) >= amount && 
            newToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        oldToken.safeTransferFrom(msg.sender, address(this), amount);
        newToken.transfer(msg.sender, amount);
    }

    function withdrawUnusedTokens() public {
        require(msg.sender == owner);
        newToken.safeTransfer(owner, newToken.balanceOf(address(this)));
    } 

}