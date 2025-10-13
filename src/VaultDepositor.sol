//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

import {IMultiChainVaultFactory} from "./interfaces/IMultiChainVaultFactory.sol";
import {IMultiChainVault} from "./interfaces/IMultiChainVault.sol";
import {IAmbImplementation} from "./cross-chain/IAmbImplementation.sol";
import {ITokenBridge} from "lib/wormhole-solidity-sdk/src/interfaces/ITokenBridge.sol";

contract VaultDepositor {

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
    uint16[] actualChainIds;

    uint256 constant MIN_AMOUNT = 1e6;
    uint256 constant TOTAL_RATIO = 100;

    address public actualAmbImplementation;

    uint256 GAS_LIMIT = 500_000;

    uint32 private nonce;

    mapping(address user => mapping(uint256 chainId => uint256 depositedAmount)) balance;
    mapping(address token => bool whitelisted) isTokenWhitelisted;


    constructor(uint16[] memory _initialChainIdsaddress, address _multiChainVaultFactory, address _actualAmbImplementation, address _tokenBridge) {
        multiChainVaultFactory = IMultiChainVaultFactory(_multiChainVaultFactory);
        actualChainIds = _initialChainIdsaddress;
        actualAmbImplementation = _actualAmbImplementation;
        tokenBridge = ITokenBridge(_tokenBridge);
    }

    function deposit(uint256 amount, uint256 chainsAmnt, address token) public  {
        if(!isTokenWhitelisted) {
            revert(); // @task se debe crear un custom error
        }
        if(chainsAmnt > 5 || chainsAmnt < 1) {
            revert(); // @task se debe crear un custom error
        }
        if(amount < MIN_AMOUNT) {
            revert(); // @task se debe crear un custom error
        }

        for(uint256 i = 0; i < chainsAmnt; ++i) {
            uint16 chainId = actualChainIds[i];
            uint256 chainRatio = 0; // @task hay que hacer una funcion que alamacene el chainRatio (osea la porcion del amount que se lleva cada chain)
            uint256 amountToChain = (amount * chainRatio) / TOTAL_RATIO - 1; // -1 to avoid problems
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
            IAmbImplementation(actualAmbImplementation).sendMessage(chainId, address(0), payload);
            // unchecked {
            //     balance[msg.sender][chainId] += amountToChain;
            // }
        }
    }
    //Should be called once the cross-chain message is processed on the other chain




}