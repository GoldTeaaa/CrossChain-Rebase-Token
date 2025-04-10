// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {console} from "forge-std/Test.sol";

contract Vault {
    // We need to pass the token adress to the constructor
    // create a deposit function that mints tokens to the user
    // create a redeem function that burns tokens from the user
    // create a way to add rewards to the vault
    error Vault__redeemFailed();

    event depositMintedToken(address indexed user, uint256 indexed amount);
    event redeemToken(address indexed user, uint256 indexed amount);

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    /**
     * @notice Deposit the amount of minted tokens in the rebase token of the user to the vault
     */
    function deposit() external payable {
        // deposit the amount of minted tokens in the rebase token of the user to the vault
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit depositMintedToken(msg.sender, msg.value);
    }

    /**
     * @notice Redeem the amount of minted tokens in the rebase token of the user to the vault
     * @param amount The amount of tokens to redeem
     */
    function redeem(uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = i_rebaseToken.balanceOf(msg.sender);
        }

        console.log("AMOUNT AFTER MAX: ", amount);
        // 1. Burn the tokens from the user
        i_rebaseToken.burn(msg.sender, amount);
        // 2. We need to send the user ETH

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Vault__redeemFailed();
        }

        emit redeemToken(msg.sender, amount);
    }

    /**
     * @notice Get the address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }

    receive() external payable {}
}
