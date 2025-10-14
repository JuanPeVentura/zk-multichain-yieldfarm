//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MultiChainVault is AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /** Events */

    event FundsTransfered(address indexed user, uint256 indexed amount);

    constructor(address[] memory _owners) {
        for(uint256 i = 0; i < _owners.length; ++i) {
            grantRole(OWNER_ROLE, _owners[i]);
        }
    }

    function withdrawToken(address _token, uint256 _amount) external onlyRole(OWNER_ROLE) {
        IERC20(_token).transfer(msg.sender, _amount);
        emit FundsTransfered(msg.sender, _amount);
    }
}