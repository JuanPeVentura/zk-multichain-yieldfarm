// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import {IAmbImplementation} from "../IAmbImplementation.sol";

contract MessageSender is IAmbImplementation{
    IWormholeRelayer internal wormholeRelayer;
    uint256 constant GAS_LIMIT = 50000;
    address vaultDepositor;

    constructor(address _wormholeRelayer, address _vaultDepositor) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        vaultDepositor = _vaultDepositor;
    }

    function quoteCrossChainCost(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function sendMessage(
        uint16 targetChain,
        address targetAddress,
        bytes memory message
    ) external payable {
        if(msg.sender != vaultDepositor) {
            revert(); //@task añadir custom error
        }
        uint256 cost = quoteCrossChainCost(targetChain);

        require(
            msg.value >= cost,
            "Insufficient funds for cross-chain delivery"
        );

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            message,
            0,
            GAS_LIMIT
        );
    }
}