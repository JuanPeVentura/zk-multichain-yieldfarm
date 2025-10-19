//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {ERC4626, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
    IMultiChainVaultFactory factory;
    ITokenBridge tokenBridge;
    IUniswapV2Router02 uniswapV2Router;
    /**
     * @dev Lista de 5 chain ids, las cuales se obtienen de forma off-chain, y son usadas para 
     */
    uint16 actualChainId;


    uint256 constant MIN_AMOUNT = 1e6;
    uint256 constant TOTAL_RATIO = 100;

    address private actualAmbImplementation;

    uint256 GAS_LIMIT = 500_000;

    uint32 private nonce;

    // mapping(address user => mapping(uint256 chainId => uint256 depositedAmount)) balance;
    mapping(address user => uint16 chainid) actualUserChainId;
    mapping(address token => bool whitelisted) isTokenWhitelisted;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");


    address feeReceiver;
    uint256 fee;

    address governor;


    //** Custom errors */

    // write custom errors here
    error InvalidFeeReceiver();


    //** Modifiers */




    modifier onlyAmbImplementation() {
        if(msg.sender != actualAmbImplementation) {
            revert();
        }
        _;
    }

    modifier onlyGovernor() {
        if(msg.sender != governor) {
            revert();
        }
        _;
    }
    
    

    constructor(address[] memory _owners, uint16 _initialChainId ,address _factory, address _actualAmbImplementation, address _tokenBridge,address _asset, address _uniswapV2Router, address _initialFeeReceiver, address _governor) ERC4626(IERC20(_asset)) ERC20("Vault Depositor", "vDEPOSIT") {
        factory = IMultiChainVaultFactory(_factory);
        actualChainId = _initialChainId;
        actualAmbImplementation = _actualAmbImplementation;
        tokenBridge = ITokenBridge(_tokenBridge);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        feeReceiver = _initialFeeReceiver;
        governor = _governor;
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
        if(actualUserChainId[msg.sender] != 0 && actualUserChainId[msg.sender] != actualChainId) {
            revert();
        } 
        _deposit(amount, token, receiver, msg.sender);
    }

    //Should be called once the cross-chain message is processed on the other chain
    function finalizeDeposit(bytes memory payload, bytes32 sourceAddress, uint16 sourceChain) external onlyAmbImplementation() {
        Message memory message = abi.decode(payload, (Message));
        address user = address(uint160(uint256(sourceAddress)));
        if(message.msgType != 2) {
            revert();
        }
        address msgSourceUser = message.sourceUser;
        uint256 amount = message.amount;
        actualUserChainId[user] = actualChainId;
        _mint(msgSourceUser, amount);
    }


    function withdraw(uint256 amount) external {
        if(actualUserChainId[msg.sender] != actualChainId) {
            revert();
        }
        _withdraw(amount, false);
    }


    function finalizeWithdraw(bytes memory payload, bytes32 sourceAddress, uint16 sourceChain) external override onlyAmbImplementation() {
        Message memory message = abi.decode(payload, (Message));
        require(message.msgType == 4, "Invalid message type for finalize withdraw");
        address msgSourceUser = message.sourceUser;
        uint256 amount = message.amount;
        uint256 feeAmount = (amount * fee) / 10000;
        uint256 finalAmount = amount - feeAmount;
        IERC20(asset()).transfer(feeReceiver, feeAmount);
        IERC20(asset()).transfer(msgSourceUser, finalAmount);
    }


    //** Chain Migration funcions should be called by the user to update chain */


    function migrateChain() external {
        if(actualUserChainId[msg.sender] == actualChainId) {
            revert(); /** user have already updated chain */
        }
        uint256 sharesOldChain = IERC20(address(this)).balanceOf(msg.sender);
        _withdraw(sharesOldChain, true);
    }

    function finalizeChainMigration(bytes memory payload, bytes32 sourceAddress, uint16 sourceChain) external onlyAmbImplementation(){
        Message memory message = abi.decode(payload, (Message));
        require(message.msgType == 6, "Invalid message type for finalize chain update");
        address msgSourceUser = message.sourceUser;
        uint256 amount = message.amount;

        uint16 chainId = actualChainId;
        IERC20(asset()).approve(address(tokenBridge), amount);
        tokenBridge.transferTokens(asset(), amount, chainId, bytes32(0), 0, nonce++);
        address user = address(uint160(uint256(sourceAddress)));

        // Send croos chain payload to dst chain using some amb implementation
        message = Message({
            msgType: 1, // 1 is msg type for deposits
            amount: amount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: user
        });
        bytes memory payload = abi.encode(message);
        address multiChainVault = factory.chainIdToVault(chainId);
        actualUserChainId[user] = actualChainId;
        IAmbImplementation(actualAmbImplementation).sendMessage(chainId, multiChainVault, payload); // this is the modular implementation, it's brings
    }

    /** Chain migration function, should be called by the owner to update chain id */

    function setChainid(uint16 _chainid) external onlyRole(OWNER_ROLE) {
        if(actualChainId == _chainid){
            return;
        }
        
        actualChainId = _chainid;
    }



    /** External functions */

    function setAmbImplementation(address _newAmbImplementation) external onlyRole(OWNER_ROLE) {
        actualAmbImplementation = _newAmbImplementation;
    }

    function totalAssets() public view override returns (uint256) {
        // This should return the total assets managed across all chains
        // For now, returning 0 as cross-chain asset tracking needs to be implemented
        return 0;
    }

    function approveToken(address token, address spender, uint256 amount) external onlyRole(OWNER_ROLE) {
        IERC20(token).approve(spender, amount);
    }

    function revokeApproval(address token, address spender) external onlyRole(OWNER_ROLE) {
        IERC20(token).approve(spender, 0);
    }

    function whitelistToken(address token, bool whitelist) external onlyRole(OWNER_ROLE) {
        if(whitelist){
            require(isTokenWhitelisted[token] == false);
            isTokenWhitelisted[token] = true;
            return;
        }

        require(isTokenWhitelisted[token] == true);
        isTokenWhitelisted[token] = false;
    }

    

    function setFeeReceiver(address _newFeeReceiver) external onlyRole(OWNER_ROLE) {
        if(_newFeeReceiver == address(0)) revert InvalidFeeReceiver();
        feeReceiver = _newFeeReceiver;
    }


    //@task this is going to be managed by the dao
    function setFee(uint256 _newFee) external onlyGovernor {
        if(_newFee > 10000) revert(); // Max 100%
        if(_newFee < 300) revert(); // Max 100%
        fee = _newFee;
    }

    function updateChainid(uint16 _chainid) external onlyRole(OWNER_ROLE) {
        if(_chainid == actualChainId) {
            revert();
        }
        if(_chainid == uint16(0)){
            revert();
        }
        actualChainId = _chainid;
    }




    /** Interrnal functions */


    function _withdraw(uint256 amount, bool isChainMigration) internal {
        uint256 assets = previewWithdraw(amount);


        _burn(msg.sender, amount);
        
        Message memory message = Message({
            msgType: isChainMigration ? 5 : 3, // 3 is msg type for withdrawals and 5 for chain migrations
            amount: amount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: msg.sender
        });
        
        bytes memory payload = abi.encode(message);
        address multiChainVault = factory.chainIdToVault(actualChainId);
        IAmbImplementation(actualAmbImplementation).sendMessage(actualChainId, multiChainVault, payload);
    }

    function _deposit(uint256 amount,address token ,address receiver, address onBehalfOf) internal {
        if(!isTokenWhitelisted[token]) {
            revert(); // @task create custom error
        }

        if(amount < MIN_AMOUNT) {
            revert(); // @task create custom error
        }

        uint16 chainId = actualChainId;

        IERC20(token).transferFrom(msg.sender, address(this), amount);


        // Swaping token for the vault (address this) asset
        IERC20(token).approve(address(uniswapV2Router), amount);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = asset();
        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
        uint256 swappedAmount = amounts[1];


        // Bridging tokens using wormhole 
        //@task maybe here would be better to approve address(this).balance of the asset()
        IERC20(asset()).approve(address(tokenBridge), swappedAmount);
        tokenBridge.transferTokens(asset(), swappedAmount, chainId, bytes32(0), 0, nonce++);

        // Send croos chain payload to dst chain using some amb implementation
        Message memory message = Message({
            msgType: 1, // 1 is msg type for deposits
            amount: amount,
            messageCreator: address(this),
            sourceChain: uint16(block.chainid),
            sourceUser: onBehalfOf
        });
        bytes memory payload = abi.encode(message);
        address multiChainVault = factory.chainIdToVault(chainId);
        IAmbImplementation(actualAmbImplementation).sendMessage(chainId, multiChainVault, payload); // this is the modular implementation, it's brings
    }


    /** Non transferable logic */

    function transfer(address, uint256) public pure override(ERC20, IERC20)  returns (bool) {
        revert();
    }

    function transferFrom(address, address, uint256) public pure override(ERC20, IERC20)  returns (bool) {
        revert();
    }

    function approve(address, uint256) public pure override(ERC20, IERC20)  returns (bool) {
        revert();
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            revert();
        }

        super._update(from, to, value);
    }
}