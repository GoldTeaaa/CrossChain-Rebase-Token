// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title RebaseToken
 *     @author Handay
 *     @notice This is a crosschain rebase token that incentivises users to deposit into a vault
 *     @notice The interest rate in the smart contract can only decreaes and the rebase token can 
 *     @notice Each user will have their own interest rate from their first join time to the protocol
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256, uint256);

    event interestRateSet(uint256);

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISSION_FACTOR = 1e18;

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {
        // _setRoleAdmin(DEFAULT_ADMIN_ROLE, adminRole);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice this can lead to centralized access granting, becasuse the owner can selective choose who can get the mint and burn role.
     * @param account The account to grant the mint and burn role
     */
    function grantMintAndBurnRole(address account) external onlyOwner {
        grantRole(MINT_AND_BURN_ROLE, account);
    }

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit interestRateSet(s_interestRate);
    }

    /**
     * @notice this is the principle balance of the user before any interest has been added
     * @param user The user to get the principle balance
     */
    function principleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // Removed to redeem function in vault
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }

        // mint is needed here to prevent remain interest that not yet accrued to the balance. If the user b
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of token that have actually been minted)
        uint256 principleBalance = super.balanceOf(_user);
        if(principleBalance == 0){
            return 0;
        }
        // multiply the principle balance by the interest rate that has accumulated in time
        return (principleBalance * _calculateUserInterestRateSinceLastUpdate(_user)) / PRECISSION_FACTOR;
    }

    /**
     * @notice this function used to mint the interest by substracting the latest balance of the user added by the interest rate with the principal balance of the user (the balance before interest was added)
     * @param user The user to mint the interest
     */
    function _mintAccruedInterest(address user) internal {
        // 1. find their current balance of rebase tokens that have minted to the user -> principle balance
        uint256 previousBalance = super.balanceOf(user);

        // 2. calculate their current balance including any interest -> balanceOf
        uint256 currentBalanceWithInterest = balanceOf(user);

        // calculate the number of tokens that need to be minted to the user
        uint256 balanceIncrease = currentBalanceWithInterest - previousBalance;

        // set the users last updated timestamp
        s_userLastUpdatedTimeStamp[user] = block.timestamp;

        // call _mint to mint the tokens to the user
        _mint(user, balanceIncrease);
    }

    /**
     * @notice Transfer tokens from one user to anotherset
     * /**
     * @notice Transfer tokens from one user to another
     * @param sender The sender of the tokens
     * @param recipient The recipient of the tokens
     * @param amount The amount of tokens to transfer
     * @return true if the transfer was successful
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(sender);
        }
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender];
        }
        bool success = super.transferFrom(sender, recipient, amount);
        return success;
    }

    /**
    @notice override the transfer function to add interest to the recipient and store the recipient interest rate
    @param recipient The recipient of the tokens
    @param amount The amount of tokens to transfer
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);

        if(amount == type(uint256).max){
            amount = balanceOf(msg.sender);
        }
        if(balanceOf(recipient) == 0){
            s_userInterestRate[recipient] = s_userInterestRate[msg.sender];
        }
        bool success = super.transfer(recipient, amount);
        return success;
    }

    /**
     * @notice Calculate the interest rate since the last update
     * @param _user The user to calculate the interest rate for
     * @return linearInterest rate that has accumulated since last update
     */
    function _calculateUserInterestRateSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // calculate interest that has been accumulated
        // deposit 10 tokens
        // Interest Rate 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 + (10*0.5*2);
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISSION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function getCurrentInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getInterestRateOf(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

}