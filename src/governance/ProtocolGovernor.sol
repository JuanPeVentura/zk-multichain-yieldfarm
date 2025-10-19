//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

import {Governor} from "lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorVotes} from "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";

contract ProtocolGovernor is Governor, GovernorVotes {
    constructor(string memory _name) Governor(_name){

    }


}