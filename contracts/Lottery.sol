// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Lottery is Ownable {
    address payable[] private _players;
    uint256 private _usdEntranceFee;
    AggregatorV3Interface internal _ethUsdPriceFeed;

    constructor(uint256 usdEntranceFee_, address priceFeedAddress_) public {
        _usdEntranceFee = usdEntranceFee_ * (10 ** 18);
        _ethUsdPriceFeed = AggregatorV3Interface(priceFeedAddress_);
    }

    function enter() public payable {
        _players.push(payable(msg.sender));
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = _ethUsdPriceFeed.latestRoundData();
        uint256 decimals = _ethUsdPriceFeed.decimals();

        uint256 adjustedPrice = uint256(price) * (10 ** (18 - decimals));
        uint256 costToEnter = (_usdEntranceFee * 10 ** 18) / adjustedPrice;

        return costToEnter;
    }
}