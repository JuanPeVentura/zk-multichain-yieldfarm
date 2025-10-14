// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IMultiChainVaultFactory {
    function chainIdToVault(uint16 chainId) external view returns (address);
    function RegisterNewVault(address vaultAddress, uint16 chainId) external;
}
