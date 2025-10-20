// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Message} from "../cross-chain/IAmbSenderImplementation.sol";

interface IMultiChainVault {
    function processOp(Message memory message, uint16 sourceChain) external;
}