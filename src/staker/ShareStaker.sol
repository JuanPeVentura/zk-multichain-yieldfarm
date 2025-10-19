// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IShareStaker} from "../interfaces/IShareStaker.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {GovToken} from "../governance/GovToken.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";


/// @title ShareStaker
/// @notice permit stake "shares" (ERC20/4626) and mint gov tokens as reward.
abstract contract ShareStaker is IShareStaker {
    IERC20 shares;

    address public govToken;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public totalStaked;

    mapping(address user => Deposit deposit) deposits;


    constructor(address _shares, address _govToken) {
        shares=IERC20(_shares);
        govToken = _govToken;
    }

    function stake(uint256 amount) external {
        _stake(amount, msg.sender);
    }
    
    function unstake(uint256 amount) external {
        _unstake(amount, msg.sender);
    }

    
    function claimRewards() external {
        _claimRewards(msg.sender);
    }

    function _claimRewards(address _onBehalfOf) internal {
        _earned(_onBehalfOf);
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        Deposit storage deposit = deposits[_onBehalfOf];
        uint256 toMint = deposit.pendingRewards;
        deposit.lastRewarded = block.timestamp;
        deposit.pendingRewards=0;
        if(toMint > 0) {
            GovToken(govToken).mint(_onBehalfOf, toMint);
            emit RewardPaid(_onBehalfOf, toMint);
        }
    }   

    function _earned(address _account)internal returns(uint256 toMint){
        Deposit storage deposit = deposits[_account];
        deposit.pendingRewards = Math.mulDiv(block.timestamp - deposit.lastRewarded, rewardRate * deposit.amount, totalStaked); 
    }

    function lastTimeRewardApplicable() public view returns(uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalStaked;
    }

    function _stake(uint256 amount, address _onBehalfOf) internal {
        shares.transferFrom(_onBehalfOf, address(this), amount);
        Deposit storage deposit = deposits[_onBehalfOf];
        deposits[_onBehalfOf].amount += amount;
        deposits[_onBehalfOf].lastDeposited = block.timestamp;
        deposits[_onBehalfOf].lastRewarded = block.timestamp;
        totalStaked+=amount;
        emit Staked(_onBehalfOf, amount);
    }

    function _unstake(uint256 amount, address _onBehalfOf) internal {
        Deposit storage deposit = deposits[_onBehalfOf];
        if(deposit.amount < amount){
            revert();
        }
        deposits[_onBehalfOf].amount -= amount;
        totalStaked-=amount;
        shares.transfer(_onBehalfOf, amount);
        emit Unstaked(_onBehalfOf, amount);
    }
    



    function notifyRewardAmount(uint256 duration, uint256 amount) external {
        if(duration <= 0) {
            revert();
        }
        if(block.timestamp > periodFinish) {
            rewardRate = amount / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / duration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardAdded(amount);
    }
    


}