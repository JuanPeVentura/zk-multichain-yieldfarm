interface IAavePool {
struct ReserveData {
        uint256 configuration; // Campo 1 (256 bits)
        uint128 liquidityIndex; // Campo 2 (128 bits)
        uint128 variableBorrowIndex; // Campo 3 (128 bits)
        uint128 liquidityRate; // Campo 4 - ESTE ES EL QUE BUSCAMOS
        // No necesitamos declarar el resto de los campos.
    }

    function getReserveData(address asset) external view returns (ReserveData memory);

    // Función de depósito: deposita el 'asset' y recibe aTokens a cambio
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    // Función de retiro: quema los aTokens (implícitamente) y devuelve el 'asset'
    // 'to' es la dirección que recibirá el token subyacente (ej. USDC)
    // Devuelve la cantidad retirada, que puede ser 'amount' o la cantidad total disponible
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}