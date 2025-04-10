// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    error RebaseTokenTest__giftToVaultFailed();

    address public owner = makeAddr("owner"); //0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D
    address public user = makeAddr("user");
    address public receiver = makeAddr("receiver");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    /**
     * @notice dynamically add liquidity to the vault with the amount
     */
    function addLiquidityToTheVaultForRedeem(uint256 amount) public {
        (bool success,) = payable(address(vault)).call{value: amount}("");
        if (!success) revert RebaseTokenTest__giftToVaultFailed();
    }

    function testInterestRate() public {
        vm.startPrank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(5e18);
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        // vm.assume(amount > 1e5);
        amount = bound(amount, 1e4, type(uint96).max);

        //1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        //2. Check the balance of the user before any interest accrued
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance : ", startBalance);
        assertEq(startBalance, amount);

        // 3. Check the balance again after Warp
        vm.warp(block.timestamp + 1 hours);
        uint256 firstWarpBalance = rebaseToken.balanceOf(user);
        console.log("firstWarpBalance : ", firstWarpBalance);
        assertGt(firstWarpBalance, startBalance);

        // 4. Warp the time again and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 secondWarpBalance = rebaseToken.balanceOf(user);
        console.log("secondWarpBalance : ", secondWarpBalance);
        assertGt(secondWarpBalance, firstWarpBalance);

        // extra, Check the interest accrued are the same in the same timeframe
        uint256 firstOneHourInterest = firstWarpBalance - startBalance;
        uint256 secondOneHourInterest = secondWarpBalance - firstWarpBalance;
        console.log(firstOneHourInterest, secondOneHourInterest);
        assertApproxEqAbs(firstOneHourInterest, secondOneHourInterest, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        //deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        console.log("amount is: ", amount);

        //redeem
        console.log("Rebase token balance: ", rebaseToken.balanceOf(user));
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        //check if the balance is added after redeem
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        amount = bound(amount, 1e5, type(uint96).max);

        //deposit
        vm.deal(user, amount);

        vm.prank(user);
        vault.deposit{value: amount}();
        // assertEq(rebaseToken.balanceOf(user), amount);
        console.log("amount is: ", amount);

        // warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterWarp = rebaseToken.balanceOf(user);
        assertGt(balanceAfterWarp, amount);

        vm.deal(user, balanceAfterWarp);
        vm.prank(user);
        addLiquidityToTheVaultForRedeem(balanceAfterWarp);

        uint256 vaultBalance = address(vault).balance;
        console.log("Vault balance: ", vaultBalance);
        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 userBalanceAfterRedeem = address(user).balance;
        assertEq(userBalanceAfterRedeem, balanceAfterWarp);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5, type(uint128).max);
        amountToSend = bound(amountToSend, 1e5, amount);

        //deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.stopPrank();

        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 receiverBalance = rebaseToken.balanceOf(receiver);
        assertEq(userBalance, amount);
        assertEq(receiverBalance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(receiver, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 receiverBalanceAfterTransfer = rebaseToken.balanceOf(receiver);
        assertEq(userBalanceAfterTransfer, amount - amountToSend);
        assertEq(receiverBalanceAfterTransfer, amountToSend);

        uint256 userInterestRate = rebaseToken.getInterestRateOf(user);
        uint256 receiverInterestRate = rebaseToken.getInterestRateOf(receiver);
        assertEq(userInterestRate, 5e10);
    }

    function testAccessRole(uint256 interestRate) public {
        // Cannot set interest rate if not owner
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(6e10);

        // Cannot mint and burn if not authorized role
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, 1e18, rebaseToken.getInterestRate());
    }

    function testPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        //deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vm.stopPrank();

        //The principle amount stored in the ERC20 contract unchanged because its not modified like in the RebaseToken
        vm.warp(block.timestamp + 1 hours);
        uint256 principleAmount = rebaseToken.principleBalanceOf(user);
        assertEq(principleAmount, amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }
}
