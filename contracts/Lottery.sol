// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] private _players;
    address payable private _recentWinner;
    uint256 private _usdEntranceFee;
    AggregatorV3Interface internal _ethUsdPriceFeed;
    uint256 private _randomness;
    enum LOTTERY_STATE {
        OPEN, 
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE lotteryState;
    uint256 private _fee;
    bytes32 private _keyHash;

    constructor(
        uint256 usdEntranceFee_, 
        address priceFeedAddress_, 
        address vrfCoordinator_, 
        address link_,
        uint256 fee_,
        bytes32 keyHash_
    ) 
    public 
    VRFConsumerBase(vrfCoordinator_, link_) 
    Ownable() {
        _usdEntranceFee = usdEntranceFee_ * (10 ** 18);
        _ethUsdPriceFeed = AggregatorV3Interface(priceFeedAddress_);
        lotteryState = LOTTERY_STATE.CLOSED;
        _fee = fee_;
        _keyHash = keyHash_;
    }

    function enter() public payable {
        require(lotteryState == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH");
        _players.push(payable(msg.sender));
    }

    function startLottery() public onlyOwner() {
        require(lotteryState == LOTTERY_STATE.CLOSED);
        lotteryState = LOTTERY_STATE.OPEN;
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = _ethUsdPriceFeed.latestRoundData();
        uint256 decimals = _ethUsdPriceFeed.decimals();

        uint256 adjustedPrice = uint256(price) * (10 ** (18 - decimals));
        uint256 costToEnter = (_usdEntranceFee * 10 ** 18) / adjustedPrice;

        return costToEnter;
    }

    function endLottery() public onlyOwner() {
        /*uint256(
            keccack256(
                abi.encodePacked(
                    nonce,
                    msg.sender,
                    block.difficulty,
                    block.timestamp
                )
            )
        ) % players.length;*/
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(_keyHash, _fee);
    }

    function fulfillRandomness(bytes32 requestId_, uint256 randomness_) internal override {
        require(lotteryState == LOTTERY_STATE.CALCULATING_WINNER);
        require(randomness_ > 0);
        uint256 winnerIndex = randomness_ % _players.length;
        _recentWinner = _players[winnerIndex];
        _recentWinner.transfer(address(this).balance);
        _players = new address payable[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
        _randomness = randomness_;
    }
}