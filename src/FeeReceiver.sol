//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.18;

// ----------------- Openzeppelin Imports -----------------

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MultiChainVault is AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /** Events */

    event FundsTransfered(address indexed user, uint256 indexed amount);
    address[] owners = new address[](2);

    constructor(address[] memory _owners) {
        for(uint256 i = 0; i < _owners.length; ++i) {
            grantRole(OWNER_ROLE, _owners[i]);
            owners[i] = _owners[i];
        }
    }

    function withdrawToken(address _token) external onlyRole(OWNER_ROLE) {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(owners[0], balance / 2);
        IERC20(_token).transfer(owners[1], balance / 2 );
        emit FundsTransfered(msg.sender, balance);
    }
}