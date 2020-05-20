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
import "./HegicERCPool.sol";
import "./HegicETHPool.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic put options
 * @notice Put options contract
 */
abstract contract HegicOptions is Ownable, SpreadLock {
    using SafeMath for uint256;

    Option[] public options;
    uint256 public impliedVolRate = 18000;
    uint256 public maxSpread = 95; //%
    uint256 constant priceDecimals = 1e8;
    uint256 constant activationTime = 15 minutes;
    AggregatorInterface public priceProvider;
    IUniswapFactory public exchanges;
    IERC20 token;
    ILiquidityPool public pool;
    OptionType private optionType;
    bool public override highSpreadLockEnabled;

    event Create(
        uint256 indexed id,
        address indexed account,
        uint256 settlementFee,
        uint256 totalFee
    );
    event Exercise(uint256 indexed id, uint256 exchangeAmount);
    event Expire(uint256 indexed id);
    enum State {Active, Exercised, Expired}
    enum OptionType {Put, Call}
    struct Option {
        State state;
        address payable holder;
        uint256 strikeAmount;
        uint256 amount;
        uint256 expiration;
        uint256 activation;
    }

    /**
     * @param DAI The address of the DAI token
     * @param pp The address of the ChainLink ETH/USD price feed contract
     * @param ex The address of the Uniswap Factory
     * @param _type Put or call contract type
     */
    constructor(
        IERC20 DAI,
        AggregatorInterface pp,
        IUniswapFactory ex,
        OptionType _type
    ) public {
        token = DAI;
        priceProvider = pp;
        exchanges = ex;
        optionType = _type;
    }

    /**
     * @notice Used to adjust prices
     * @param value New IVRate value
     */
    function setImpliedVolRate(uint256 value) public onlyOwner {
        require(value >= 10000, "ImpliedVolRate limit is too small");
        impliedVolRate = value;
    }

    /**
     * @notice Used to adjust the spread limit
     * @param value New maxSpread value
     */
    function setMaxSpread(uint256 value) public onlyOwner {
        require(value <= 95, "Spread limit is too large");
        maxSpread = value;
    }

    /**
     * @notice Used to get actual option's prices
     * @param period Option period in seconds (1 days <= period <= 8 weeks)
     * @param amount Option amount
     * @param strike Strike price of the option
     * @return total Total price needs to be paid
     * @return settlementFee Amount to be distributed between the HEGIC token holders
     * @return strikeFee Amount that covers the price difference in the ITM options
     * @return slippageFee Compensates the slippage during the exercising process
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
            uint256 slippageFee,
            uint256 periodFee
        )
    {
        uint256 currentPrice = uint256(priceProvider.latestAnswer());
        settlementFee = getSettlementFee(amount);
        periodFee = getPeriodFee(amount, period, strike, currentPrice);
        slippageFee = getSlippageFee(amount);
        strikeFee = getStrikeFee(amount, strike, currentPrice);
        total = periodFee.add(slippageFee).add(strikeFee);
    }

    /**
     * @notice Creates ATM option
     * @param period Option period in seconds (1 days <= period <= 8 weeks)
     * @param amount Option amount
     * @return optionID Created option's ID
     */
    function createATM(uint256 period, uint256 amount)
        public
        payable
        returns (uint256 optionID)
    {
        return create(period, amount, uint256(priceProvider.latestAnswer()));
    }

    /**
     * @notice Creates a new option
     * @param period Option period in sconds (1 days <= period <= 8 weeks)
     * @param amount Option amount
     * @param strike Strike price of an option
     * @return optionID Created option's ID
     */
    function create(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) public payable returns (uint256 optionID) {
        (uint256 total, uint256 settlementFee, , , ) = fees(
            period,
            amount,
            strike
        );
        uint256 strikeAmount = strike.mul(amount) / priceDecimals;

        require(strikeAmount > 0, "Amount is too small");
        require(settlementFee < total, "Premium is too small");
        require(period >= 1 days, "Period is too short");
        require(period <= 8 weeks, "Period is too long");
        require(msg.value == total, "Wrong value");
        payable(owner()).transfer(settlementFee);

        optionID = options.length;
        options.push(
            Option(
                State.Active,
                msg.sender,
                strikeAmount,
                amount,
                now + period,
                now + activationTime
            )
        );

        sendPremium(total.sub(settlementFee));
        lockFunds(options[optionID]);
        emit Create(optionID, msg.sender, settlementFee, total);
    }

    /**
     * @notice Exercise your active option
     * @param optionID ID of your option
     */
    function exercise(uint256 optionID) public payable {
        Option storage option = options[optionID];

        require(option.expiration >= now, "Option has expired");
        require(option.activation <= now, "Option has not been activated yet");
        require(option.holder == msg.sender, "Wrong msg.sender");
        require(option.state == State.Active, "Wrong state");

        option.state = State.Exercised;
        swapFunds(option);

        uint256 amount = exchange();
        emit Exercise(optionID, amount);
    }

    /**
     * @notice Unlock array of options
     * @param optionIDs array of options
     */
    function unlockAll(uint256[] memory optionIDs) public {
        for (uint256 i; i < optionIDs.length; unlock(optionIDs[i++])) {}
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
        emit Expire(optionID);
    }

    /**
     * @notice Counts settlementFee
     * @param amount Option amount
     * @return fee Settlment fee amount
     */
    function getSettlementFee(uint256 amount)
        internal
        pure
        returns (uint256 fee)
    {
        fee = amount / 100;
    }

    /**
     * @notice Counts periodFee
     * @param amount Option amount
     * @param period Option period in seconds (1 days <= period <= 8 weeks)
     * @param strike Strike price of the option
     * @param currentPrice Current ETH price
     * @return fee Period fee amount
     */
    function getPeriodFee(
        uint256 amount,
        uint256 period,
        uint256 strike,
        uint256 currentPrice
    ) internal view returns (uint256 fee) {
        if (optionType == OptionType.Put)
            fee = amount
                .mul(sqrt(period / 10))
                .mul(impliedVolRate)
                .mul(strike)
                .div(currentPrice)
                .div(1e8);
        else
            fee = amount
                .mul(sqrt(period / 10))
                .mul(impliedVolRate)
                .mul(currentPrice)
                .div(strike)
                .div(1e8);
    }

    /**
     * @notice Calculates slippageFee
     * @param amount Option amount
     * @return fee Slippage fee amount
     */
    function getSlippageFee(uint256 amount)
        internal
        pure
        returns (uint256 fee)
    {
        if (amount > 10 ether) fee = amount.mul(amount) / 1e22;
    }

    /**
     * @notice Counts strikeFee
     * @param amount Option amount
     * @param strike Strike price of the option
     * @param currentPrice Current ether price
     * @return fee Strike fee amount
     */
    function getStrikeFee(
        uint256 amount,
        uint256 strike,
        uint256 currentPrice
    ) internal view returns (uint256 fee) {
        if (strike > currentPrice && optionType == OptionType.Put)
            fee = (strike - currentPrice).mul(amount).div(currentPrice);
        if (strike < currentPrice && optionType == OptionType.Call)
            fee = (currentPrice - strike).mul(amount).div(currentPrice);
    }

    function exchange() public virtual returns (uint256 exchangedAmount);

    function sendPremium(uint256 amount) internal virtual;

    function lockFunds(Option memory option) internal virtual;

    function swapFunds(Option memory option) internal virtual;

    function unlockFunds(Option memory option) internal virtual;

    /**
     * @return res Square root of the number
     */
    function sqrt(uint256 x) private pure returns (uint256 res) {
        res = x;
        uint256 z = (x + 1) / 2;
        while (z < res) (res, z) = (z, (x / z + z) / 2);
    }
}
