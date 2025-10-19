// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IStrategy {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 amount) external returns (uint256);
    function depositedAmount(address user) external returns (uint256);
    function getYieldPercentage() external view returns (uint256 percentage);
}
