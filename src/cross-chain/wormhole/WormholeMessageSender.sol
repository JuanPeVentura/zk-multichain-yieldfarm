// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeReceiver.sol";
import {IAmbSenderImplementation, Message} from "../IAmbSenderImplementation.sol";
import {IMultiChainVault} from "../../interfaces/IMultiChainVault.sol";
import {IVaultDepositor} from "../../interfaces/IVaultDepositor.sol";
import {IMultiChainVaultFactory} from "../../interfaces/IMultiChainVaultFactory.sol";

contract WormholeMessageSender is IAmbSenderImplementation {


    IWormholeRelayer internal wormholeRelayer;
    uint256 constant GAS_LIMIT = 50000;
    address factory;
    address public registrationOwner;
    mapping(uint16 => bytes32) public registeredSenders;

    
    event MessageReceived(Message message);
    event SourceChainLogged(uint16 sourceChain);

    constructor(address _wormholeRelayer, address _factory) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        registrationOwner = msg.sender;
        factory = _factory;
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

    modifier isRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
        require(
            registeredSenders[sourceChain] == sourceAddress,
            "Not registered sender"
        );
        _;
    }

    function setRegisteredSender(
        uint16 sourceChain,
        bytes32 sourceAddress
    ) public {
        require(
            msg.sender == registrationOwner,
            "Not allowed to set registered sender"
        );
        registeredSenders[sourceChain] = sourceAddress;
    }
}