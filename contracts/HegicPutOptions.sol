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

pragma solidity ^0.6.8;
import "./HegicOptions.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic ETH Put Options
 * @notice ETH Put Options Contract
 */
contract HegicPutOptions is HegicOptions {
    IUniswapV2Router01 public uniswapRouter;
    HegicERCPool public pool;
    uint256 public maxSpread = 95;
    IERC20 token;

    /**
     * @param DAI The address of DAI token contract
     * @param priceProvider The address of ChainLink ETH/USD price feed contract
     * @param _uniswapRouter The address of Uniswap Router contract
     */
    constructor(
        IERC20 DAI,
        AggregatorInterface priceProvider,
        IUniswapV2Router01 _uniswapRouter
    )
        public
        HegicOptions(priceProvider, HegicOptions.OptionType.Put)
    {
        token = DAI;
        uniswapRouter = _uniswapRouter;
        pool = new HegicERCPool(token);
        approve();
    }

    /**
     * @notice Can be used to update the contract in critical situations in the first 90 days after deployment
     */
    function transferPoolOwnership() public onlyOwner {
        require(now < contractCreationTimestamp + 90 days);
        pool.transferOwnership(owner());
    }

    /**
     * @notice Used for adjusting the spread limit
     * @param value New maxSpread value
     */
    function setMaxSpread(uint256 value) public onlyOwner {
        require(value <= 95, "Spread limit is too small");
        maxSpread = value;
    }

    /**
     * @notice Allows the ERC pool contract to receive and send tokens
     */
    function approve() public {
        token.approve(address(pool), uint256(-1));
    }

    /**
     * @notice Used for changing the lockup period
     * @param value New period value
     */
    function setLockupPeriod(uint256 value) public onlyOwner {
        require(value <= 60 days, "LockupPeriod is too small");
        pool.setLockupPeriod(value);
    }

    /**
     * @notice Sends premiums to the ERC liquidity pool contract
     */
    function sendPremium(uint256 amount) internal override returns (uint premium) {
      uint currentPrice = uint(priceProvider.latestAnswer());
      address[] memory path = new address[](2);
      path[0] = uniswapRouter.WETH();
      path[1] = address(token);
      uint[] memory amounts = uniswapRouter.swapExactETHForTokens {
          value: amount
      }(
          amount.mul(currentPrice).mul(maxSpread).div(1e10),
          path,
          address(this),
          now
      );
      premium = amounts[amounts.length - 1];
      pool.sendPremium(premium);
    }

    /**
     * @notice Locks the amount required for an option
     * @param option A specific option contract
     */
    function lockFunds(Option memory option) internal override {
        pool.lock(option.amount.mul(option.strike).div(1e8));
    }

    /**
     * @notice Sends profits in DAI from the ERC pool to a put option holder's address
     * @param option A specific option contract
     */
    function payProfit(Option memory option) internal override returns (uint profit) {
        uint currentPrice = uint(priceProvider.latestAnswer());
        require(option.strike >= currentPrice, "Current price is too high");
        profit = option.strike.sub(currentPrice).mul(option.amount).div(1e8);
        pool.send(option.holder, profit);
        unlockFunds(option);
    }

    /**
     * @notice Unlocks the amount that was locked in a put option contract
     * @param option A specific option contract
     */
    function unlockFunds(Option memory option) internal override {
        pool.unlockPremium(option.premium);
        pool.unlock(option.amount.mul(option.strike).div(1e8));
    }
}
