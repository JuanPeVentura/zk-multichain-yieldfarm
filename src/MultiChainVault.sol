//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// ----------------- Interface Imports -----------------

import {IAmbImplementation, Message} from "./cross-chain/IAmbImplementation.sol";
import {ITokenBridge} from "lib/wormhole-solidity-sdk/src/interfaces/ITokenBridge.sol";

contract MultiChainVault is ERC4626 {
    address public actualAmbImplementation;
    address vaultDepositor;

    //@task should replace it for initialize because it can't be deployed with create2 if it has a constructor.
    constructor(address _asset, address _actualAmbImplementation, address _vaultDepositor) ERC4626(_asset) {
        actualAmbImplementation = _actualAmbImplementation;
        vaultDepositor = _vaultDepositor;
    }

    function processOp(Message memory message, uint16 sourceChain) external {
        uint8 messageType = message.msgType;
        uint256 amount = message.amount;
        uint16 msgSourceChain = message.sourceChain;

        if(sourceChain != msgSourceChain) {
            revert();
        }

        if(messageType == 1 /** deposit message */) {
            _deposit(amount, sourceChain);
        } 
    } 


    function _deposit(uint256 amount, uint16 sourceChain) internal override {
        if(IERC20(_asset).balanceOf(address(this)) < amount) {
            revert();
        }
        //@task depositar en estrategias
        Message message = new Message({
            msgType: 2, // 2-> shares minting
            amount: _convertToShares(amount),// shares to mint 
            messageCreator: address(this),
            sourceChain: block.chainid
        });

        bytes payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(sourceChain, vaultDepositor,  payload);

    }
}
