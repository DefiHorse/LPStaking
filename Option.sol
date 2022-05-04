// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingOptions is Ownable {

    struct OptionsStaking {
        uint256 lockDays;
        uint256 valueAPY;
        uint256 maxPool;
        uint256 curPool;
        uint256 startTime;
        uint256 endTime;
        uint256 durationLockReward;
    }

    uint256 public countIdOptions = 3;

    mapping(uint256 => OptionsStaking) public infoOptions;

    constructor() {
        infoOptions[0] = OptionsStaking(uint256(60),uint256(60),uint256(1000000000000000000000000),uint256(0),uint256(1649934077),uint256(1682154334),uint256(600));
        infoOptions[1] = OptionsStaking(uint256(180),uint256(150),uint256(1000000000000000000000000),uint256(0),uint256(1649934077),uint256(1682154334),uint256(600));
        infoOptions[2] = OptionsStaking(uint256(360),uint256(200),uint256(1000000000000000000000000),uint256(0),uint256(1649934077),uint256(1682154334),uint256(600));
    }

    function setOptions(
        uint256[] memory _optionInfoDay,
        uint256[] memory _optionInfoAPY,
        uint256[] memory _optionInfoMaxPool, 
        uint256[] memory _optionInfoStartTime, 
        uint256[] memory _optionInfoEndTime,
        uint256[] memory _optionInfodurationLockReward
    ) public onlyOwner{
        require(_optionInfoDay.length == _optionInfoAPY.length, "SetOptions: The inputs have the same length");
        require(_optionInfoDay.length == _optionInfoMaxPool.length, "SetOptions: The inputs have the same length");
        require(_optionInfoDay.length == _optionInfoStartTime.length, "SetOptions: The inputs have the same length");
        require(_optionInfoDay.length == _optionInfoEndTime.length, "SetOptions: The inputs have the same length");
        require(_optionInfoDay.length == _optionInfodurationLockReward.length, "SetOptions: The inputs have the same length");
        for(uint256 i=0; i < _optionInfoDay.length; i++){
            OptionsStaking memory info = OptionsStaking(
                _optionInfoDay[i], 
                _optionInfoAPY[i], 
                _optionInfoMaxPool[i], 
                0,
                _optionInfoStartTime[i],
                _optionInfoEndTime[i],
                _optionInfodurationLockReward[i]
            );
            infoOptions[countIdOptions] = info;
            countIdOptions+=1;
        }
    }

    function editOptions(uint256 _ops, uint256 _maxPool, uint256 _startTime, uint256 _endTime) public onlyOwner{
        require(_ops < countIdOptions, "EditOptions: The id is not valid");
        require(_maxPool > 0, "EditOptions: The maxPool is not valid");
        require(_startTime > 0, "EditOptions: The startTime is not valid");
        require(_endTime > 0, "EditOptions: The endTime is not valid");
        require(_startTime < _endTime, "EditOptions: The startTime is not valid");
        infoOptions[_ops].maxPool = _maxPool;
        infoOptions[_ops].startTime = _startTime;
        infoOptions[_ops].endTime = _endTime;
    }
}
