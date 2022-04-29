// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./lib/TokenPrice.sol";
import "./lib/Option.sol";

contract StakingTokenLP is Pausable, Ownable, DfhPrice, StakingOptions {

    struct userInfoStaking {
        bool isActive;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        uint256 stakeOptions;
        uint256 fullLockedDays;
        uint256 valueAPY;
        uint256 reward;
    }

    struct userInfoTotal{
        uint256 totalUserStaked; 
        uint256 totalUserReward;
        uint256 totalUserRewardClaimed;
    }

    struct userStakingManage{
        userInfoStaking[] infor;
    }

    ERC20 public token;
    address public lpToken;
    mapping(bytes32 => userInfoStaking) private infoStaking;
    mapping(address => userInfoTotal) private infoTotal;

    event UsersStaking(address indexed user, uint256 amountStake, uint256 indexed option, uint256 indexed id);
    event UserUnstaking(address indexed user, uint256 claimableAmountStake, uint256 indexed option, uint256 indexed id);
    event UserReward(address indexed user, uint256 claimableReward, uint256 indexed option, uint256 indexed id);

    uint256 public totalStaked = 0;
    uint256 public totalClaimedReward = 0;
    uint256 public totalAccumulatedRewardsReleased = 0;

    constructor(ERC20 _token, address _lpToken) {
        token = _token;
        lpToken = _lpToken;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function userStake(uint256 _amountStake, uint256 _ops, uint256 _id) public whenNotPaused {
        bytes32 _value = keccak256(abi.encodePacked(_msgSender(), _ops, _id));
        require(infoStaking[_value].isActive == false, "UserStake: Duplicate id");
        OptionsStaking memory options = infoOptions[_ops];
        uint256 _curPool = options.curPool + _amountStake;
        uint256 maxPool = options.maxPool;
        require(_curPool <= maxPool, "UserStake: Max Amount");
        require(options.startTime <= block.timestamp, "UserStake: This Event Not Yet Start Time");
        require(block.timestamp <= options.endTime, "UserStake: This Event Over Time");

        ERC20(lpToken).transferFrom(msg.sender, address(this), _amountStake);

        uint256 _lockDay =  options.lockDays;
        uint256 _apy = options.valueAPY;
        uint256 _reward = _calcRewardStaking(_apy,_lockDay,_amountStake);
        uint256 _endTime = block.timestamp + _lockDay;

        if(_ops == 0) {
            _reward = 0;
            _endTime = block.timestamp;
        }

        userInfoStaking memory info =
            userInfoStaking(
                true, 
                _amountStake, 
                block.timestamp,
                _endTime,
                _ops,
                _lockDay,
                _apy,
                _reward
            );
        infoStaking[_value] = info;

        infoOptions[_ops].curPool = _curPool;
        totalStaked = totalStaked + _amountStake;
        totalAccumulatedRewardsReleased = totalAccumulatedRewardsReleased + _reward;

        emit UsersStaking(msg.sender, _amountStake, _ops, _id);

        userInfoTotal storage infoTotals  = infoTotal[_msgSender()];
        infoTotals.totalUserStaked = infoTotals.totalUserStaked + _amountStake;
        infoTotals.totalUserReward = infoTotals.totalUserReward + _reward;
    }

    function estRewardAmount(uint256 _apy, uint256 _lockDay, uint256 _amount)
        public
        view
        returns(uint256)
    {
        return _calcRewardStaking(_apy, _lockDay, _amount);
    }

    function _calcRewardStaking(uint256 _apy , uint256 _lockDay ,uint256 _amountStakeLP)
        internal
        view 
        returns(uint256)
    {
        uint256 _totalValueofLP;
        uint256 _totalSupplyofLP;
        uint256 _curPriceToken;
        (_totalValueofLP,_totalSupplyofLP, _curPriceToken) = _calcReturnedValue(lpToken);

        uint256 _reward = ((_totalValueofLP/_totalSupplyofLP) * (_amountStakeLP)) / _curPriceToken;
        uint256 _result = _reward * (_apy * (10**18) / 100) *_lockDay;
        return (_result / 365 days) / (10**18);      
    }
    
    function userUnstake(uint256 _ops, uint256 _id) public {
        bytes32 _value = keccak256(abi.encodePacked(_msgSender(), _ops,_id));
        userInfoStaking storage info = infoStaking[_value];
        OptionsStaking storage options = infoOptions[_ops];
        require(info.isActive == true, "UnStaking: Not allowed unstake two times");

        uint256 claimableAmount = _calcClaimableAmount(_value);
        require(claimableAmount > 0, "Unstaking: Nothing to claim");

        ERC20(lpToken).transfer(msg.sender,claimableAmount);
        emit UserUnstaking(msg.sender, claimableAmount, _ops, _id);

        if (_ops == 0) {
            uint256 _lockDay = (block.timestamp - info.startTime) / infoOptions[0].lockDays * infoOptions[0].lockDays;
            uint256 _reward = _calcRewardStaking(info.valueAPY, _lockDay, info.amount);

            info.fullLockedDays = _lockDay;

            info.reward = _reward;
            totalAccumulatedRewardsReleased = totalAccumulatedRewardsReleased + _reward;
        }
        info.endTime = block.timestamp;
        info.isActive = false;
        options.curPool = options.curPool - claimableAmount;
    }

    function _calcClaimableAmount(bytes32 _value)
        internal
        view 
        returns(uint256 claimableAmount)
    {
        userInfoStaking memory info = infoStaking[_value];
        if(!info.isActive) return 0;
        if(block.timestamp < info.endTime) return 0;
        claimableAmount = info.amount;
    }

    function claimReward(uint256 _ops, uint256 _id) public{
        bytes32 _value = keccak256(abi.encodePacked(_msgSender(), _ops,_id));
        uint256 _claimableReward = _calcReward(_value,_ops);
        require(_claimableReward > 0, "Reward: Nothing to claim");
        token.transfer(msg.sender,_claimableReward);

        totalClaimedReward = totalClaimedReward + _claimableReward;
        userInfoStaking storage info = infoStaking[_value];
        info.reward = 0;
        emit UserReward(msg.sender, _claimableReward, _ops, _id);
        userInfoTotal storage infoTotals  = infoTotal[_msgSender()];
        infoTotals.totalUserRewardClaimed = infoTotals.totalUserRewardClaimed + _claimableReward;
    }

    function _calcReward(bytes32 _value, uint256 _ops)
        internal
        view
        returns(uint256 claimableReward)
    {
        userInfoStaking memory info = infoStaking[_value];
        OptionsStaking storage options = infoOptions[_ops];
        uint256 releaseTime = info.endTime + options.durationLockReward;
        if(block.timestamp < releaseTime) return 0;
        claimableReward = info.reward;
    }

    function getInfoUserTotal(address account)
        public 
        view 
        returns (uint256,uint256) 
    {
        userInfoTotal memory info = infoTotal[account];
        return (info.totalUserStaked,info.totalUserReward);
    }

    function getInfoUserStaking(
        address account,
        uint256 _ops,
        uint256 _id
    ) 
        public
        view 
        returns (bool, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        bytes32 _value = keccak256(abi.encodePacked(account, _ops,_id));
        userInfoStaking memory info = infoStaking[_value];
        uint256 _reward = info.reward;
        
        if(_ops == 0)
        {
            uint256 _lockDay = (block.timestamp - info.startTime) / infoOptions[0].lockDays * infoOptions[0].lockDays;
            if(info.fullLockedDays <= _lockDay){
                _reward = _calcRewardStaking(info.valueAPY, _lockDay, info.amount);
            } else {
                _reward = 0;
            }
        }

        return (
            info.isActive,
            info.amount, 
            info.startTime,
            info.endTime,
            info.stakeOptions,
            info.fullLockedDays,
            info.valueAPY,
            _reward
        );
    }

    function estLpToToken(uint256 _amount)
        public
        view
        returns(uint256)
    {
        uint256 _totalValueofLP;
        uint256 _totalSupplyofLP;
        uint256 _curPriceToken;
        (_totalValueofLP, _totalSupplyofLP, _curPriceToken) = _calcReturnedValue(lpToken);
        return  (((_totalValueofLP / _totalSupplyofLP) * _amount) / _curPriceToken);
    }
    
    // amount BNB
    function withdrawNative(uint256 _amount) public onlyOwner {
        require(_amount > 0 , "_amount must be greater than 0");
        require( address(this).balance >= _amount ,"balanceOfNative:  is not enough");
        payable(msg.sender).transfer(_amount);
    }
    
    function withdrawToken(IERC20 _token, uint256 _amount) public onlyOwner {
        require(_amount > 0 , "_amount must be greater than 0");
        require(_token.balanceOf(address(this)) >= _amount , "balanceOfToken:  is not enough");
        _token.transfer(msg.sender, _amount);
    }
    
    // all BNB
    function withdrawNativeAll() public onlyOwner {
        require(address(this).balance > 0 ,"balanceOfNative:  is equal 0");
        payable(msg.sender).transfer(address(this).balance);
    }
  
    function withdrawTokenAll(IERC20 _token) public onlyOwner {
        require(_token.balanceOf(address(this)) > 0 , "balanceOfToken:  is equal 0");
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

    event Received(address, uint);
    receive () external payable {
        emit Received(msg.sender, msg.value);
    }
}
