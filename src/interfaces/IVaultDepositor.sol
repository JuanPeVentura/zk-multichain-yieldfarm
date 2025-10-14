//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

interface IVaultDepositor {
    function deposit(uint256 amount,address token ,address receiver) external;
    function finalizeDeposit(bytes memory payload,bytes32 sourceAddress,uint16 sourceChain) external;
    function whitelistToken(address token, bool whitelist) external;
    function setChainid(uint16 _chainid) external;
}