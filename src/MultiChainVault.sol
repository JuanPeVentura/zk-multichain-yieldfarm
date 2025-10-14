//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {ERC4626, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

// ----------------- Interface Imports -----------------

import {IAmbImplementation, Message} from "./cross-chain/IAmbImplementation.sol";
import {ITokenBridge} from "lib/wormhole-solidity-sdk/src/interfaces/ITokenBridge.sol";

contract MultiChainVault is ERC4626 {
    address public actualAmbImplementation;
    address vaultDepositor;

    //@task should replace it for initialize because it can't be deployed with create2 if it has a constructor.
    constructor(address _asset, address _actualAmbImplementation, address _vaultDepositor) ERC4626(IERC20(_asset)) ERC20("MultiChain Vault", "mVault") {
        actualAmbImplementation = _actualAmbImplementation;
        vaultDepositor = _vaultDepositor;
    }

    function processOp(Message memory message, uint16 sourceChain) external {
        uint8 messageType = message.msgType;
        uint256 amount = message.amount;
        uint16 msgSourceChain = message.sourceChain;
        address msgSourceUser = message.sourceUser;

        if(sourceChain != msgSourceChain) {
            revert();
        }

        if(messageType == 1 /** deposit message */) {
            _deposit(amount, sourceChain, msgSourceUser);
        } 
    } 


    function _deposit(uint256 amount, uint16 sourceChain, address msgSourceUser) internal {
        if(IERC20(asset()).balanceOf(address(this)) < amount) {
            revert();
        }
        //@task depositar en estrategias
        Message memory message = Message({
            msgType: 2, // 2-> shares minting
            amount: _convertToShares(amount, Math.Rounding.Floor),// shares to mint 
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: msgSourceUser
        });

        bytes memory payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(sourceChain, vaultDepositor,  payload);

    }
}
