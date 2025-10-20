//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// ----------------- Interface Imports -----------------

import {IMultiChainVaultFactory} from "./interfaces/IMultiChainVaultFactory.sol";

contract MultiChainVaultFactory is IMultiChainVaultFactory, AccessControl{

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // bytes public multiChainVaultBytecode;
    mapping(uint16 chainId => address vaultAddress) public chainIdToVault;
    

    error NotOwner(address account);

    constructor(address[] memory _owners/**, bytes memory _multiChainVaultBytecode**/) {
        // multiChainVaultBytecode = _multiChainVaultBytecode;
        for(uint256 i = 0; i < _owners.length; ++i) {
            _grantRole(OWNER_ROLE, _owners[i]);
        }
    }


    function RegisterNewVault(address vaultAddress, uint16 chainId) external onlyRole(OWNER_ROLE) {
        if(chainIdToVault[chainId] != address(0)) {
            revert();
        }

        chainIdToVault[chainId] = vaultAddress;
    }

    // function setMultiChainVaultBytecode(bytes memory _multiChainVaultBytecode) external onlyRole(OWNER_ROLE) {
    //     multiChainVaultBytecode = _multiChainVaultBytecode;
    // }
}