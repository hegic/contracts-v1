/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2020 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

pragma solidity 0.6.8;
import "./HegicOptions.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic ETH Call Options
 * @notice ETH Call Options Contract
 */
contract HegicCallOptions is HegicOptions {
    HegicETHPool public pool;

    /**
     * @param _priceProvider The address of ChainLink ETH/USD price feed contract
     */
    constructor(AggregatorInterface _priceProvider)
        public
        HegicOptions(_priceProvider, HegicOptions.OptionType.Call)
    {
        pool = new HegicETHPool();
    }

    /**
     * @notice Can be used to update the contract in critical situations in the first 90 days after deployment
     */
    function transferPoolOwnership() external onlyOwner {
        require(now < contractCreationTimestamp + 90 days);
        pool.transferOwnership(owner());
    }

    /**
     * @notice Used for changing the lockup period
     * @param value New period value
     */
    function setLockupPeriod(uint256 value) external onlyOwner {
        require(value <= 60 days, "Lockup period is too large");
        pool.setLockupPeriod(value);
    }

    /**
     * @notice Sends premiums to the ETH liquidity pool contract
     * @param amount The amount of premiums that will be sent to the pool
     */
    function sendPremium(uint amount) internal override returns (uint locked) {
        pool.sendPremium {value: amount}();
        locked = amount;
    }

    /**
     * @notice Locks the amount required for an option
     * @param option A specific option contract
     */
    function lockFunds(Option memory option) internal override {
        pool.lock(option.amount);
    }

    /**
     * @notice Sends profits in ETH from the ETH pool to a call option holder's address
     * @param option A specific option contract
     */
    function payProfit(Option memory option)
        internal
        override
        returns (uint profit)
    {
        uint currentPrice = uint(priceProvider.latestAnswer());
        require(option.strike <= currentPrice, "Current price is too low");
        profit = currentPrice.sub(option.strike).mul(option.amount).div(currentPrice);
        pool.send(option.holder, profit);
        unlockFunds(option);
    }

    /**
     * @notice Unlocks the amount that was locked in a call option contract
     * @param option A specific option contract
     */
    function unlockFunds(Option memory option) internal override {
        pool.unlockPremium(option.premium);
        pool.unlock(option.amount);
    }
}
