// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Governor} from "lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorSettings} from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorVotes} from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "lib/openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

string constant NAME = "Governor";

//Code copied from succinit

contract ProtocolGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    constructor(
        address _govToken,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumFraction
    )
        Governor(NAME)
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(IVotes(_govToken))
        GovernorVotesQuorumFraction(_quorumFraction)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 _blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(_blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
