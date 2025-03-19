// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken{
    function mint(address user, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address user) external view returns(uint256);
}