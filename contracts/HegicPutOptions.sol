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
 * @title Hegic ETH Put Options
 * @notice ETH Put Options Contract
 */
contract HegicPutOptions is HegicOptions {
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
        HegicOptions(DAI, priceProvider, uniswap, HegicOptions.OptionType.Put)
    {
        pool = new HegicERCPool(DAI);
    }

    /**
     * @notice Swaps ETH for DAI tokens and sends to the DAI liquidity pool
     * @return exchangedAmount Amount that is received from the Uniswap pool
     */
    function exchange() public override returns (uint) {
        return exchange(address(this).balance);
    }

    /**
     * @notice Swap a specific amount of ETH for DAI tokens and send it to the DAI liquidity pool
     * @param amount A specific amount to swap
     * @return exchangedAmount An amount to receive from the Uniswap pool
     */
    function exchange(uint amount) public returns (uint exchangedAmount) {
        UniswapExchangeInterface ex = exchanges.getExchange(token);
        uint exShare = ex.getEthToTokenInputPrice(1 ether);
        if(exShare > maxSpread.mul(uint(priceProvider.latestAnswer())).mul(1e8)) {
            highSpreadLockEnabled = false;
            exchangedAmount = ex.ethToTokenTransferInput {value: amount} (
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
     */
    function sendPremium(uint) override internal {
        exchange();
    }

    /**
     * @notice Locks the amount required for an option
     * @param option A specific option contract
     */
    function lockFunds(Option memory option) override internal {
        pool.lock(option.strikeAmount);
    }

    /**
     * @notice Receives ETH from the user and sends DAI tokens from the pool
     * @param option A specific option contract
     */
    function swapFunds(Option memory option) override internal {
        require(option.amount == msg.value, "Wrong msg.value");
        pool.send(option.holder, option.strikeAmount);
    }

    /**
     * @notice Locks the amount required for an option contract
     * @param option A specific option contract
     */
    function unlockFunds(Option memory option) override internal {
        pool.unlock(option.strikeAmount);
    }
}
