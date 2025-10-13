// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Message} from "../VaultDepositor.sol";

interface IMultiChainVault {
    function processOp(Message memory message, uint16 sourceChain) external;
}