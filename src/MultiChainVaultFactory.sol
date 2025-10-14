//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;


import {IMultiChainVaultFactory} from "./interfaces/IMultiChainVaultFactory.sol";

contract MultiChainVaultFactory is IMultiChainVaultFactory{

    mapping(uint16 chainId => address vaultAddress) public chainIdToVault;
    function RegisterNewVault(address vaultAddress, uint16 chainId) external {
        if(chainIdToVault[chainId] != address(0)) {
            revert();
        }

        chainIdToVault[chainId] = vaultAddress;
    }
}