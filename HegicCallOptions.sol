pragma solidity ^0.6.4;
import "./HegicOptions.sol";

contract HegicCallOptions is HegicOptions {
    constructor(IERC20 DAI, IPriceProvider pp, IUniswapFactory ex)
      HegicOptions(DAI, pp, ex, HegicOptions.OptionType.Call) public {
        pool = new HegicETHPool();
        approve();
    }

    function approve() public {
      token.approve(address(exchanges.getExchange(token)), uint(-1));
    }

    function exchange() public returns (uint exchangedAmount) { return exchange( token.balanceOf(address(this)) ); }

    function exchange(uint amount) public returns (uint exchangedAmount) {
      UniswapExchangeInterface ex = exchanges.getExchange(token);
      uint exShare =  ex.getTokenToEthInputPrice(priceProvider.currentAnswer().mul(1e10)); // 1e18
      if( exShare > maxSpread.mul(0.01 ether) )
        exchangedAmount = ex.tokenToEthTransferInput(amount, 1, now + 1 minutes, address(pool));
    }

    function create(uint period, uint amount) public payable returns (uint optionID) {
      return create(period, amount, priceProvider.currentAnswer());
    }

    function create(uint period, uint amount, uint strike) public payable returns (uint optionID) {
        (uint premium, uint fee,,,) = fees(period, amount, strike);
        uint strikeAmount = strike.mul(amount) / priceDecimals;

        require(strikeAmount > 0,"Amount is too small");
        require(fee > premium,   "Period is too short");
        require(period >= 1 days,"Period is too short");
        require(period <= 8 weeks,"Period is too long");
        require(msg.value == premium, "Wrong value");

        payable( owner() ).transfer(fee);
        pool.lock(amount);
        payable(address(pool)).transfer(premium.sub(fee));
        optionID = options.length;
        options.push (Option(State.Active, msg.sender, strikeAmount, amount, now + period, now + activationTime));

        emit Create(optionID, msg.sender, fee, premium);
    }

    function exercise(uint optionID) public {
        Option storage option = options[optionID];

        require(option.expiration >= now, 'Option has expired');
        require(option.activation <= now, 'Option has not been activated yet');
        require(option.holder == msg.sender, "Wrong msg.sender");
        require(option.state == State.Active, "Wrong state");

        token.transferFrom(option.holder, address(this), option.strikeAmount);
        uint amount = exchange();
        pool.send(option.holder, option.amount);
        option.state = State.Exercised;

        emit Exercise(optionID, amount);
    }

}
