// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeReceiver.sol";
import {IAmbImplementation} from "../IAmbImplementation.sol";
import {IMultiChainVault} from "../../interfaces/IMultiChainVault.sol";
import {IVaultDepositor} from "../../interfaces/IVaultDepositor.sol";

contract WormoleImplementation is IAmbImplementation {


    IWormholeRelayer internal wormholeRelayer;
    uint256 constant GAS_LIMIT = 50000;
    address vaultDepositor;
    address public registrationOwner;
    mapping(uint16 => bytes32) public registeredSenders;

    
    event MessageReceived(Message message);
    event SourceChainLogged(uint16 sourceChain);

    constructor(address _wormholeRelayer, address _vaultDepositor) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        vaultDepositor = _vaultDepositor;
        registrationOwner = msg.sender;
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

    // Update receiveWormholeMessages to include the source address check
    function receiveMessage(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32
    ) public payable override isRegisteredSender(sourceChain, sourceAddress) returns(Message memory message) {
        require(
            msg.sender == address(wormholeRelayer),
            "Only the Wormhole relayer can call this function"
        );

        // Decode the payload to extract the message
        message = abi.decode(payload, (Message));
        uint8 t = message.msgType;

        if(t != 0 /** It's a operation */ && t != 2) {
            /** @task should implement function that return multiChainVault, passing the chainID */
            IMultiChainVault(address(0)).processOp(message, sourceChain);
        } else if(t == 2) {
            IVaultDepositor(vaultDepositor).finalizeDeposit(payload,sourceAddress, sourceChain);
        }

        // Example use of sourceChain for logging
        if (sourceChain != 0) {
            emit SourceChainLogged(sourceChain);
        } 

        // Emit an event with the received message
        emit MessageReceived(message);
    }
}