//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovToken is ERC20  {
    address shareStaker;
    constructor(address _shareStaker) ERC20("Governor token", "GVNTK") {
        shareStaker = _shareStaker;
    }

    function mint(address _user, uint256 _amount) external {
        if(msg.sender != shareStaker) {
            revert();
        }
        _mint(_user, _amount);
    }
}