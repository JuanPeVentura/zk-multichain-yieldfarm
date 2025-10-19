//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

import {ERC20Votes, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

contract GovToken is ERC20Votes  {
    address shareStaker;
    constructor(address _shareStaker) ERC20("Governor token", "GVNTK") EIP712("Governor token", "1") {
        shareStaker = _shareStaker;
    }

    function mint(address _user, uint256 _amount) external {
        if(msg.sender != shareStaker) {
            revert();
        }
        _mint(_user, _amount);
    }
}