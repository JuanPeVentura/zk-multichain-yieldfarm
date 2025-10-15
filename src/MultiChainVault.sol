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

import {IStrategy} from "./interfaces/IStrategy.sol";

contract MultiChainVault is ERC4626, AccessControl {

    struct Strategy {
        address addr;
        uint256 allocation;
    }
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    address public actualAmbImplementation;
    address vaultDepositor;
    uint256 public totalAllocation;


    /** Strategies data */
    Strategy[] public strategies;
    mapping(address => bool) public isStrategy;
    mapping(uint256 strategyId => Strategy strategy) idToStrategy;

    error NotOwner(address account);
    error NotAmbImplementation(address account);

    modifier onlyAmbImplementation(address account) {
        if(account != actualAmbImplementation) {
            revert NotAmbImplementation(account);
        }
        _;
    }


    //@task should replace it for initialize because it can't be deployed with create2 if it has a constructor.
    constructor(address[] memory _owners,address _asset, address _actualAmbImplementation, address _vaultDepositor) ERC4626(IERC20(_asset)) ERC20("MultiChain Vault", "mVault") {
        actualAmbImplementation = _actualAmbImplementation;
        vaultDepositor = _vaultDepositor;
        for(uint256 i = 0; i < _owners.length; ++i) {
            grantRole(OWNER_ROLE, _owners[i]);
        }
    }


    function processOp(Message memory message, uint16 sourceChain) public {
        uint8 messageType = message.msgType;
        uint256 amount = message.amount;
        uint16 msgSourceChain = message.sourceChain;
        address msgSourceUser = message.sourceUser;

        if(sourceChain != msgSourceChain) {
            revert();
        }

        if(messageType == 1 /** deposit message */) {
            _deposit(amount, sourceChain, msgSourceUser);
        } else if(messageType == 3 /** withdraw message */) {
            _withdraw(amount, sourceChain, msgSourceUser);
        } else if(messageType == 5) {
            _manageChainMigration(amount, sourceChain, msgSourceUser);
        }
    } 

    
    /** EXTERNAL */
    
     function addStrategy(address _strategy, uint256 _allocation) external onlyRole(OWNER_ROLE) {
        require(!isStrategy[_strategy], "Strategy already exists");
        require(_allocation > 0, "Allocation must be greater than 0");
        require(totalAllocation + _allocation <= 100, "Total allocation cannot exceed 100");

        strategies.push(Strategy({addr: _strategy, allocation: _allocation}));
        isStrategy[_strategy] = true;
        totalAllocation += _allocation;
    }

    function removeStrategy(address _strategy) external onlyRole(OWNER_ROLE) {
        require(isStrategy[_strategy], "Strategy does not exist");

        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].addr == _strategy) {
                totalAllocation -= strategies[i].allocation;
                strategies[i] = strategies[strategies.length - 1];
                strategies.pop();
                isStrategy[_strategy] = false;
                break;
            }
        }
    }

    function updateStrategyAllocation(address _strategy, uint256 _newAllocation) external onlyRole(OWNER_ROLE) {
        require(isStrategy[_strategy], "Strategy does not exist");
        require(_newAllocation > 0, "Allocation must be greater than 0");

        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].addr == _strategy) {
                uint256 oldAllocation = strategies[i].allocation;
                require(totalAllocation - oldAllocation + _newAllocation <= 100, "Total allocation cannot exceed 100");
                strategies[i].allocation = _newAllocation;
                totalAllocation = totalAllocation - oldAllocation + _newAllocation;
                break;
            }
        }
    }


    /** INTERNAL */


    function _deposit(uint256 amount, uint16 sourceChain, address msgSourceUser) internal {
        if(IERC20(asset()).balanceOf(address(this)) < amount) {
            revert();
        }

        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 amountToInvest = amount * strategies[i].allocation / 100;
            IERC20(asset()).transfer(strategies[i].addr, amountToInvest);
            //@task should implement strategy deposit
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

    function _withdraw(uint256 amount, uint16 sourceChain, address msgSourceUser) internal {
        amount = _convertToAssets(amount, Math.Rounding.Floor);
        uint256 withdrawnAmount = 0;
        for (uint256 i = strategies.length; i > 0; i--) {
            if (withdrawnAmount >= amount) {
                break;
            }
            uint256 amountToWithdraw = amount - withdrawnAmount;
            uint256 strategyDepositedFunds = IStrategy(strategies[i-1].addr).depositedAmount(msgSourceUser);
            withdrawnAmount += strategyDepositedFunds + withdrawnAmount > amount ? amount - withdrawnAmount : strategyDepositedFunds;
        }

        if(withdrawnAmount < amount) {
            revert(); // Not enough liquidity
        }

        Message memory message = Message({
            msgType: 4, // 4 -> finalize withdrawal
            amount: withdrawnAmount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: msgSourceUser
        });

        bytes memory payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(sourceChain, vaultDepositor,  payload);
    }

    function _manageChainMigration(uint256 amount, uint16 sourceChain, address msgSourceUser) internal {
        amount = _convertToAssets(amount, Math.Rounding.Floor);
        uint256 withdrawnAmount = 0;
        for (uint256 i = strategies.length; i > 0; i--) {
            if (withdrawnAmount >= amount) {
                break;
            }
            // uint256 amountToWithdraw = amount - withdrawnAmount;
            uint256 strategyDepositedFunds = IStrategy(strategies[i-1].addr).depositedAmount(msgSourceUser);
            uint256 amountToWithdraw = strategyDepositedFunds + withdrawnAmount > amount ? amount - withdrawnAmount : strategyDepositedFunds;
            withdrawnAmount += IStrategy(strategies[i-1].addr).withdraw(amountToWithdraw);
        }

        if(withdrawnAmount < amount) {
            revert(); // Not enough liquidity
        }

        Message memory message = Message({
            msgType: 6, // 6 -> finalize chain update
            amount: withdrawnAmount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: msgSourceUser
        });

        bytes memory payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(sourceChain, vaultDepositor,  payload);
    }
}
