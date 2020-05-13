/*
 * Hegic
 * Copyright (C) 2020 Hegic
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

pragma solidity ^0.6.6;
import "./HegicOptions.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic ETH Call Options
 * @notice ETH Call Options Contract
 */
contract HegicCallOptions is HegicOptions {
    /**
     * @param DAI The address of the DAI token
     * @param priceProvider The address of the ChainLink ETH/USD price feed contract
     * @param uniswap The address of the Uniswap Factory
     */
    constructor(
        IERC20 DAI,
        AggregatorInterface priceProvider,
        IUniswapFactory uniswap
    )
        public
        HegicOptions(DAI, priceProvider, uniswap, HegicOptions.OptionType.Call)
    {
        pool = new HegicETHPool();
        approve();
    }

    /**
     * @notice Allows the Uniswap pool to swap the assets
     */
    function approve() public {
        token.approve(address(exchanges.getExchange(token)), uint256(-1));
    }

    /**
     * @notice Swap a specific amount of DAI tokens for ETH and send it to the ETH liquidity pool
     * @return exchangedAmount An amount to receive from the Uniswap pool
     */
    function exchange() public override returns (uint256 exchangedAmount) {
        return exchange(token.balanceOf(address(this)));
    }

    /**
     * @notice Swap a specific amount of DAI tokens for ETH and send it to the ETH liquidity pool
     * @param amount A specific amount to swap
     * @return exchangedAmount An amount that was received from the Uniswap pool
     */
    function exchange(uint256 amount) public returns (uint256 exchangedAmount) {
        UniswapExchangeInterface ex = exchanges.getExchange(token);
        uint256 exShare = ex.getTokenToEthInputPrice(
            uint256(priceProvider.latestAnswer()).mul(1e10)
        );
        if (exShare > maxSpread.mul(0.01 ether)) {
            highSpreadLockEnabled = false;
            exchangedAmount = ex.tokenToEthTransferInput(
                amount,
                1,
                now + 1 minutes,
                address(pool)
            );
        } else {
            highSpreadLockEnabled = true;
        }
    }

    /**
     * @notice Distributes the premiums between the liquidity providers
     * @param amount Premiums amount that will be sent to the pool
     */
    function sendPremium(uint256 amount) internal override {
        payable(address(pool)).transfer(amount);
    }

    /**
     * @notice Locks the amount required for an option
     * @param option A specific option contract
     */
    function lockFunds(Option memory option) internal override {
        pool.lock(option.amount);
    }

    /**
     * @notice Receives DAI tokens from the user and sends ETH from the pool
     * @param option A specific option contract
     */
    function swapFunds(Option memory option) internal override {
        require(msg.value == 0, "Wrong msg.value");
        require(
            token.transferFrom(
                option.holder,
                address(this),
                option.strikeAmount
            ),
            "Insufficient funds"
        );
        pool.send(option.holder, option.amount);
    }

    /**
     * @notice Locks the amount required for an option contract
     * @param option A specific option contract
     */
    function unlockFunds(Option memory option) internal override {
        pool.unlock(option.amount);
    }
}
