// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title IShareStaker
/// @notice Interfaz completa para un contrato Staker que permite stakear "shares" (ERC20/4626) y mintear/otorgar gov tokens como recompensa.
///         Pensada para usarse como base en tu protocolo: stake de shares -> emisión de gov tokens.
interface IShareStaker {

    struct Deposit {
        uint256 amount;
        uint256 lastDeposited;
        uint256 lastRewarded;
        uint256 pendingRewards;
    }

    // -----------------------------
    // Events
    // -----------------------------

    /// @notice Se emite cuando un usuario hace stake
    /// @param user Dirección del usuario
    /// @param amount Cantidad de shares stacked
    event Staked(address indexed user, uint256 indexed amount);

    /// @notice Se emite cuando un usuario hace unstake
    /// @param user Dirección del usuario
    /// @param amount Cantidad de shares retirados
    event Unstaked(address indexed user, uint256 indexed amount);

    /// @notice Se emite cuando se pagan recompensas (gov tokens)
    /// @param user Dirección que recibe la recompensa
    /// @param reward Cantidad de gov tokens pagados
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Se emite cuando se agrega una recompensa al pool
    /// @param reward Cantidad de tokens de recompensa añadidos
    event RewardAdded(uint256 reward);

    /// @notice Se emite cuando se actualiza la tasa de recompensa
    /// @param newRate Nueva reward rate
    event RewardRateUpdated(uint256 newRate);

    /// @notice Pausa el contrato (solo admin)
    event Paused(address account);

    /// @notice Reanuda el contrato (solo admin)
    event Unpaused(address account);

    /// @notice Operador agregado/quitado
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);

    // -----------------------------
    // Core staking actions
    // -----------------------------

    /// @notice Stakea `amount` de shares en nombre del sender
    /// @param amount Cantidad de shares a stakear
    function stake(uint256 amount) external;

    /// @notice Retira `amount` de shares y actualiza recompensas
    /// @param amount Cantidad a retirar
    function unstake(uint256 amount) external;

    /// @notice Reclama las recompensas devengadas sin retirar los shares
    function claimRewards() external;


    // -----------------------------
    // Admin / reward management
    // -----------------------------

    /// @notice Notifica que se agregó `reward` tokens al contrato (para distribuir durante `duration()`)
    /// @param reward Cantidad de gov tokens añadidos como pool de recompensas
    function notifyRewardAmount(uint256 reward) external;


    // -----------------------------
    // View / read-only helpers
    // -----------------------------



    /// @notice Reward por token acumulado hasta ahora
    /// @return rewardPerToken Valor acumulado por token
    function rewardPerToken() external view returns (uint256);

    /// @notice Último timestamp aplicado para reward
    /// @return timestamp
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Tasa de recompensa actual
    /// @return rate Reward rate
    function rewardRate() external view returns (uint256);

    /// @notice Momento en que termina el periodo de recompensa actual
    /// @return timestamp
    function periodFinish() external view returns (uint256);

    /// @notice Duración del periodo de recompensa en segundos
    /// @return durationSeconds
    function duration() external view returns (uint256);

    /// @notice Dirección del gov token que se mintea como recompensa
    /// @return addressGov
    function govToken() external view returns (address);


    /// @notice Devuelve la recompensa acumulada por token en una unidad con 18 decimales
    /// @return rewardPerTokenStored
    function rewardPerTokenStored() external view returns (uint256);

}
