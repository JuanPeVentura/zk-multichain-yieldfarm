// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IWormholeReceiver.sol";
import {IAmbReceiverImplementation} from "../IAmbReceiverImplementation.sol";
import {Message} from "../IAmbSenderImplementation.sol";
import {IMultiChainVault} from "../../interfaces/IMultiChainVault.sol";
import {IVaultDepositor} from "../../interfaces/IVaultDepositor.sol";
import {IMultiChainVaultFactory} from "../../interfaces/IMultiChainVaultFactory.sol";

contract WormholeMessageReceiver is IAmbReceiverImplementation {

    IWormholeRelayer internal wormholeRelayer;
    uint256 constant GAS_LIMIT = 50000;
    address vaultDepositor;
    address factory;
    address public registrationOwner;
    mapping(uint16 => bytes32) public registeredSenders;

    
    event MessageReceived(Message message);
    event SourceChainLogged(uint16 sourceChain);

    constructor(address _wormholeRelayer, address _vaultDepositor, address _factory) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        vaultDepositor = _vaultDepositor;
        registrationOwner = msg.sender;
        factory = _factory;
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
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) public payable override isRegisteredSender(sourceChain, sourceAddress) returns(Message memory message) {
        require(
            msg.sender == address(wormholeRelayer),
            "Only the Wormhole relayer can call this function"
        );

        // Decode the payload to extract the message
        message = abi.decode(payload, (Message));
        uint8 t = message.msgType;


        if(t == 1 || t == 3 || t == 5) {
            /** @task should implement function that return multiChainVault, passing the chainID */
            address multiChainVault = IMultiChainVaultFactory(factory).chainIdToVault(message.sourceChain);
            IMultiChainVault(multiChainVault).processOp(message, sourceChain);
        } else if(t == 2) {
            IVaultDepositor(vaultDepositor).finalizeDeposit(payload,sourceAddress, sourceChain);
        } else if(t == 4) {
            IVaultDepositor(vaultDepositor).finalizeWithdraw(payload,sourceAddress, sourceChain);
        } else if(t == 6) {
            IVaultDepositor(vaultDepositor).finalizeChainMigration(payload,sourceAddress, sourceChain);
        }

        // Example use of sourceChain for logging
        if (sourceChain != 0) {
            emit SourceChainLogged(sourceChain);
        } 

        // Emit an event with the received message
        emit MessageReceived(message);

        return message;
    }
}