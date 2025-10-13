//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

import {IMultiChainVaultFactory} from "./interfaces/IMultiChainVaultFactory.sol";
import {IMultiChainVault} from "./interfaces/IMultiChainVault.sol";
import {IAmbImplementation} from "./cross-chain/IAmbImplementation.sol";
import {ITokenBridge} from "lib/wormhole-solidity-sdk/src/interfaces/ITokenBridge.sol";

contract VaultDepositor {

    /**
     * @dev This one is the main contracts, este, desplegado en la main chain del protocolo (e.g polygon), interactua con cada vault de cada chain, dependiendo de cual chains estan seleccionadas (obtenidas off chain) 
     * despues, el multiChainVault, es desplegado uno en cada chain, cada multi chain vault tiene distintas estrategies, las cual usa para maximizar rendimeintos en esa chain. este automaticamente obtendra las strategias mas rentables.
     * 
     */

    struct Message {
        uint8 msgType; // 1 -> deposit, 2 -> withdraw
        uint256 amount; // per chain
        address messageCreator;
        uint16 sourceChain;
    }
    /** @dev El multi chain vault factory despliega multiChainVault usando create2. 
     *  Relaciona cada vault con su chainId correspondiente, en un mapping.
     **/
    IMultiChainVaultFactory multiChainVaultFactory;
    ITokenBridge tokenBridge;
    /**
     * @dev Lista de 5 chain ids, las cuales se obtienen de forma off-chain, y son usadas para 
     */
    uint16 actualChainId;

    uint256 constant MIN_AMOUNT = 1e6;
    uint256 constant TOTAL_RATIO = 100;

    address public actualAmbImplementation;

    uint256 GAS_LIMIT = 500_000;

    uint32 private nonce;

    mapping(address user => mapping(uint256 chainId => uint256 depositedAmount)) balance;
    mapping(address token => bool whitelisted) isTokenWhitelisted;


    constructor(uint16 memory _initialChainId, address _multiChainVaultFactory, address _actualAmbImplementation, address _tokenBridge) {
        multiChainVaultFactory = IMultiChainVaultFactory(_multiChainVaultFactory);
        actualChainId = _initialChainId;
        actualAmbImplementation = _actualAmbImplementation;
        tokenBridge = ITokenBridge(_tokenBridge);
    }

    function deposit(uint256 amount, address token) public  {
        if(!isTokenWhitelisted) {
            revert(); // @task se debe crear un custom error
        }

        if(amount < MIN_AMOUNT) {
            revert(); // @task se debe crear un custom error
        }

        uint16 chainId = actualChainId;
        //@task implementar el simstema de mensajeria y recepcion de mensajes cross-chain
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        Message memory message = Message({
            msgType: 1,
            amount: amountToChain,
            messageCreator: msg.sender,
            sourceChain: uint16(block.chainid)
        });

        tokenBridge.transferTokens(token, amountToChain, chainId, bytes32(0), 0, nonce++);
        bytes memory payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(chainId, address(0), payload); // this is the modular implementation, it's brings

    
    }
    //Should be called once the cross-chain message is processed on the other chain




}