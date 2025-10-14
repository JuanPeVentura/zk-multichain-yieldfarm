//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// ----------------- Interface Imports -----------------

import {IVaultDepositor} from "./interfaces/IVaultDepositor.sol";
import {IMultiChainVaultFactory} from "./interfaces/IMultiChainVaultFactory.sol";
import {IMultiChainVault} from "./interfaces/IMultiChainVault.sol";
import {IAmbImplementation, Message} from "./cross-chain/IAmbImplementation.sol";
import {ITokenBridge} from "lib/wormhole-solidity-sdk/src/interfaces/ITokenBridge.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router.sol";

contract VaultDepositor is ERC4626, AccessControl, IVaultDepositor{

    /**
     * @dev This one is the main contracts, este, desplegado en la main chain del protocolo (e.g polygon), interactua con cada vault de cada chain, dependiendo de cual chains estan seleccionadas (obtenidas off chain) 
     * despues, el multiChainVault, es desplegado uno en cada chain, cada multi chain vault tiene distintas estrategies, las cual usa para maximizar rendimeintos en esa chain. este automaticamente obtendra las strategias mas rentables.
     * 
     */

    /** @dev El multi chain vault factory despliega multiChainVault usando create2. 
     *  Relaciona cada vault con su chainId correspondiente, en un mapping.
     **/
    IMultiChainVaultFactory multiChainVaultFactory;
    ITokenBridge tokenBridge;
    IUniswapV2Router02 uniswapV2Router;
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

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");


    //** Custom errors */

    // write custom errors here


    //** Modifiers */

    modifier onlyOwner(address account) {
        if(!hasRole(OWNER_ROLE, account)) {
            revert();
        }
    }

    constructor(uint16 memory _initialChainId,address[] _owners ,address _multiChainVaultFactory, address _actualAmbImplementation, address _tokenBridge,address _asset, address _uniswapV2Router) ERC4626(_asset) {
        multiChainVaultFactory = IMultiChainVaultFactory(_multiChainVaultFactory);
        actualChainId = _initialChainId;
        actualAmbImplementation = _actualAmbImplementation;
        tokenBridge = ITokenBridge(_tokenBridge);
        uniswapV2Router = IUniswapV2Router02(uniswapV2Router);
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        for(uint256 i = 0; i < _owners.length; ++i) {
            grantRole(OWNER_ROLE, _owners[i]);
        }
    }

    /**
     * 
     * @param amount The amount of tokens to deposit in token
     * @param token  The token that the user have to send
     * @param receiver The receiver of the shares
     */

    function deposit(uint256 amount,address token ,address receiver) public  override {
        if(!isTokenWhitelisted) {
            revert(); // @task create custom error
        }

        if(amount < MIN_AMOUNT) {
            revert(); // @task create custom error
        }

        uint16 chainId = actualChainId;

        IERC20(token).transferFrom(msg.sender, address(this), amount);


        // Swaping token for the vault (address this) asset
        address[] path = new address[](2);
        path[0] = token;
        path[1] = asset;
        uniswapV2Router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);


        // Bridging tokens using wormhole 
        tokenBridge.transferTokens(asset, amountToChain, chainId, bytes32(0), 0, nonce++);

        // Send croos chain payload to dst chain using some amb implementation
        Message memory message = Message({
            msgType: 1, // 1 is msg type for deposits
            amount: amount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: msg.sender
        });
        bytes memory payload = abi.encode(message);
        IAmbImplementation(actualAmbImplementation).sendMessage(chainId, address(0), payload); // this is the modular implementation, it's brings
    }



    //Should be called once the cross-chain message is processed on the other chain
    function finalizeDeposit(bytes memory payload, bytes32 sourceAddress, uint16 sourceChain) external {
        Message message = abi.decode(payload, (Message));
        address msgSourceUser = message.sourceUser;
        uint256 amount = message.amount;
        _mint(msgSourceUser, amount);
    }


    function whitelistToken(address token, bool whitelist) external onlyOwner(msg.sender) {
        if(whitelist){
            require(isTokenWhitelisted[token] == false);
            isTokenWhitelisted[token] = true;
            return;
        }

        require(isTokenWhitelisted[token] == true);
        isTokenWhitelisted[token] = false;
    }

    function setChainid(uint16 _chainid) external onlyOwner(msg.sender) {
        if(actualChainId == _chainid){
            return;
        }
        
        actualChainId = _chainid;
    }


}