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
import "./HegicERCPool.sol";
import "./HegicETHPool.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic: On-chain Options Trading Protocol on Ethereum
 * @notice Hegic Protocol Options Contract
 */
abstract
contract HegicOptions is Ownable {
    using SafeMath for uint256;

    address payable public settlementFeeRecipient;
    Option[] public options;
    uint256 public impliedVolRate;
    uint256 internal constant PRICE_DECIMALS = 1e8;
    uint256 internal contractCreationTimestamp;
    AggregatorInterface public priceProvider;
    OptionType private optionType;

    event Create(
        uint256 indexed id,
        address indexed account,
        uint256 settlementFee,
        uint256 totalFee
    );

    event Exercise(uint256 indexed id, uint256 profit);
    event Expire(uint256 indexed id, uint256 premium);
    enum State {Active, Exercised, Expired}
    enum OptionType {Put, Call}

    struct Option {
        State state;
        address payable holder;
        uint256 strike;
        uint256 amount;
        uint256 premium;
        uint256 expiration;
    }

    /**
     * @param pp The address of ChainLink ETH/USD price feed contract
     * @param _type Put or Call type of an option contract
     */
    constructor(AggregatorInterface pp, OptionType _type) public {
        priceProvider = pp;
        optionType = _type;
        settlementFeeRecipient = payable(owner());
        impliedVolRate = 6500;
        contractCreationTimestamp = now;
    }

    /**
     * @notice Used for adjusting the options prices while balancing asset's implied volatility rate
     * @param value New IVRate value
     */
    function setImpliedVolRate(uint256 value) external onlyOwner {
        require(value >= 1000, "ImpliedVolRate limit is too small");
        impliedVolRate = value;
    }

    /**
     * @notice Used for changing settlementFeeRecipient
     * @param recipient New settlementFee recipient address
     */
    function setSettlementFeeRecipient(address payable recipient) external onlyOwner {
        require(recipient != address(0));
        settlementFeeRecipient = recipient;
    }

    /**
     * @notice Creates a new option
     * @param period Option period in sconds (1 days <= period <= 4 weeks)
     * @param amount Option amount
     * @param strike Strike price of an option
     * @return optionID Created option's ID
     */
    function create(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) external payable returns (uint256 optionID) {
        (uint256 total, uint256 settlementFee, , ) = fees(
            period,
            amount,
            strike
        );
        uint256 strikeAmount = strike.mul(amount) / PRICE_DECIMALS;

        require(strikeAmount > 0, "Amount is too small");
        require(settlementFee < total, "Premium is too small");
        require(period >= 1 days, "Period is too short");
        require(period <= 4 weeks, "Period is too long");
        require(msg.value == total, "Wrong value");

        uint256 premium = sendPremium(total.sub(settlementFee));
        optionID = options.length;
        options.push(
            Option(
                State.Active,
                msg.sender,
                strike,
                amount,
                premium,
                now + period
            )
        );

        emit Create(optionID, msg.sender, settlementFee, total);
        lockFunds(options[optionID]);
        settlementFeeRecipient.transfer(settlementFee);
    }

    /**
     * @notice Exercise your active option
     * @param optionID ID of your option
     */
    function exercise(uint256 optionID) external {
        Option storage option = options[optionID];

        require(option.expiration >= now, "Option has expired");
        require(option.holder == msg.sender, "Wrong msg.sender");
        require(option.state == State.Active, "Wrong state");

        option.state = State.Exercised;
        uint256 profit = payProfit(option);

        emit Exercise(optionID, profit);
    }

    /**
     * @notice Unlock array of options
     * @param optionIDs array of options
     */
    function unlockAll(uint256[] calldata optionIDs) external {
        for (uint256 i = 0; i < optionIDs.length; i++) {
            unlock(optionIDs[i]);
        }
    }

    /**
     * @notice Used for getting the actual options prices
     * @param period Option period in seconds (1 days <= period <= 4 weeks)
     * @param amount Option amount
     * @param strike Strike price of an option
     * @return total Total price to be paid
     * @return settlementFee Amount to be distributed to the HEGIC token holders
     * @return strikeFee Amount that covers the price difference in the ITM options
     * @return periodFee Option period fee
     */
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike
    )
        public
        view
        returns (
            uint256 total,
            uint256 settlementFee,
            uint256 strikeFee,
            uint256 periodFee
        )
    {
        uint256 currentPrice = uint256(priceProvider.latestAnswer());
        settlementFee = getSettlementFee(amount);
        periodFee = getPeriodFee(amount, period, strike, currentPrice);
        strikeFee = getStrikeFee(amount, strike, currentPrice);
        total = periodFee.add(strikeFee);
    }

    /**
     * @notice Unlock funds locked in the expired options
     * @param optionID ID of the option
     */
    function unlock(uint256 optionID) public {
        Option storage option = options[optionID];
        require(option.expiration < now, "Option has not expired yet");
        require(option.state == State.Active, "Option is not active");
        option.state = State.Expired;
        unlockFunds(option);
        emit Expire(optionID, option.premium);
    }

    /**
     * @notice Calculates settlementFee
     * @param amount Option amount
     * @return fee Settlment fee amount
     */
    function getSettlementFee(uint256 amount)
        internal
        pure
        returns (uint256 fee)
    {
        return amount / 100;
    }

    /**
     * @notice Calculates periodFee
     * @param amount Option amount
     * @param period Option period in seconds (1 days <= period <= 4 weeks)
     * @param strike Strike price of the option
     * @param currentPrice Current ETH price
     * @return fee Period fee amount
     *
     * amount < 1e30        |
     * impliedVolRate < 1e10| => amount * impliedVolRate * strike < 1e60 < 2^uint256
     * strike < 1e20 ($1T)  |
     *
     * in case amount * impliedVolRate * strike >= 2^256
     * transaction will be reverted by the SafeMath
     */
    function getPeriodFee(
        uint256 amount,
        uint256 period,
        uint256 strike,
        uint256 currentPrice
    ) internal view returns (uint256 fee) {
        if (optionType == OptionType.Put)
            return amount
                .mul(sqrt(period))
                .mul(impliedVolRate)
                .mul(strike)
                .div(currentPrice)
                .div(PRICE_DECIMALS);
        else
            return amount
                .mul(sqrt(period))
                .mul(impliedVolRate)
                .mul(currentPrice)
                .div(strike)
                .div(PRICE_DECIMALS);
    }

    /**
     * @notice Calculates strikeFee
     * @param amount Option amount
     * @param strike Strike price of an option
     * @param currentPrice Current price of ETH
     * @return fee Strike fee amount
     */
    function getStrikeFee(
        uint256 amount,
        uint256 strike,
        uint256 currentPrice
    ) internal view returns (uint256 fee) {
        if (strike > currentPrice && optionType == OptionType.Put)
            return strike.sub(currentPrice).mul(amount).div(currentPrice);
        if (strike < currentPrice && optionType == OptionType.Call)
            return currentPrice.sub(strike).mul(amount).div(currentPrice);
        return 0;
    }

    function sendPremium(uint256 amount)
        internal
        virtual
        returns (uint256 locked);

    function payProfit(Option memory option)
        internal
        virtual
        returns (uint256 amount);

    function lockFunds(Option memory option) internal virtual;
    function unlockFunds(Option memory option) internal virtual;

    /**
     * @return result Square root of the number
     */
    function sqrt(uint256 x) private pure returns (uint256 result) {
        result = x;
        uint256 k = x.add(1).div(2);
        while (k < result) (result, k) = (k, x.div(k).add(k).div(2));
    }
}
