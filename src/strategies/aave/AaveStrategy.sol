// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAavePool} from "./IAavePool.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract AaveStrategy is IStrategy {
    address public immutable AAVE_POOL_ADDRESS;
    address public immutable ASSET_TOKEN; // El token subyacente (ej. USDC)
    
    // Constante para la conversión de Ray (1e27) a 18 decimales (1e18)
    uint256 private constant RAY_TO_WAD_RATIO = 1e9; // 10^(27-18) = 1e9

    // La dirección del Vault/Manager que llama a la estrategia (para enviar los fondos al retirar)
    address public immutable VAULT_ADDRESS; 

    constructor(address _aavePool, address _assetToken, address _vaultAddress) {
        AAVE_POOL_ADDRESS = _aavePool;
        ASSET_TOKEN = _assetToken;
        VAULT_ADDRESS = _vaultAddress;
    }
    mapping(address user => uint256 depositedAmount) public depositedAmount;
    /// @notice Obtiene el APY base (liquidityRate) del contrato de Aave y lo estandariza.
    function getYieldPercentage() public view override returns (uint256 percentage) {
        // Llama a getReserveData del Pool de Aave
        IAavePool.ReserveData memory reserveData = IAavePool(AAVE_POOL_ADDRESS).getReserveData(ASSET_TOKEN);

        // Convierte la tasa de Ray (1e27) a 18 decimales (1e18)
        percentage = reserveData.liquidityRate / RAY_TO_WAD_RATIO;

        return percentage;
    }

    /// @notice Deposita fondos en el Aave Pool.
    function deposit(uint256 amount) external override returns(uint256) {
        // 1. **(Asumido)**: El Vault ya transfirió el 'amount' de ASSET_TOKEN a este contrato (AaveStrategy).
        
        // 2. Aprobar el Pool de Aave para que pueda mover los tokens de esta estrategia.
        IERC20(ASSET_TOKEN).approve(AAVE_POOL_ADDRESS, amount);

        // 3. Llamar a 'supply' en el Pool de Aave.
        // El 'onBehalfOf' (quién recibe los aTokens) debe ser esta estrategia para rastrear la posición.
        IAavePool(AAVE_POOL_ADDRESS).supply(
            ASSET_TOKEN,
            amount,
            address(this), // Los aTokens se acuñan y se guardan aquí.
            0 // referralCode
        );

        return amount;
    }

    /// @notice Retira fondos del Aave Pool y los envía al Vault.
    /// @param amount La cantidad del token subyacente a retirar.
    function withdraw(uint256 amount) external override returns(uint256){
        // 1. Llamar a 'withdraw' en el Pool de Aave.
        // Esta función automáticamente quema los aTokens de esta estrategia.
        // El 'to' es la dirección que recibe el token subyacente (ej. USDC, DAI).
        uint256 actualAmountWithdrawn = IAavePool(AAVE_POOL_ADDRESS).withdraw(
            ASSET_TOKEN,
            amount,
            VAULT_ADDRESS // El token retirado debe ir directamente al Vault
        );

        return actualAmountWithdrawn;
        
        // **OPCIONAL**: Se podría verificar que el 'actualAmountWithdrawn' es >= 'amount'
        // require(actualAmountWithdrawn >= amount, "Withdrawal error");
    }
}