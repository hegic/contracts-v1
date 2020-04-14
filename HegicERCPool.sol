pragma solidity ^0.6.4;
import "./Interfaces.sol";

contract HegicERCPool is IERCLiquidityPool, Ownable, ERC20("Hegic DAI LP Token", "writeDAI"){
    using SafeMath for uint256;
    uint public lockedAmount;
    IERC20 public override token;

    constructor(IERC20 _token) public { token = _token; }

    function availableBalance() public view returns (uint balance) {balance = totalBalance().sub(lockedAmount);}
    function totalBalance() public override view returns (uint balance) { balance = token.balanceOf(address(this));}

    function provide(uint amount) public {
        if(totalSupply().mul(totalBalance()) == 0) _mint(msg.sender, amount * 1000);
        else _mint(msg.sender, amount.mul(totalSupply()).div(totalBalance()));
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint amount) public {
        require(amount <= availableBalance(), "Pool: Insufficient unlocked funds");
        uint burn = amount.mul(totalSupply()).div(totalBalance());
        require(burn <= balanceOf(msg.sender), "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");
        _burn(msg.sender, burn);
        token.transfer(msg.sender, amount);
    }

    function shareOf(address user) public view returns (uint share){
        if(totalBalance() > 0) share = totalBalance()
            .mul(balanceOf(user))
            .div(totalSupply());
    }

    function lock(uint amount) public override onlyOwner {
        require(
            lockedAmount.add(amount).mul(10).div( totalBalance() ) < 8,
            "Pool: Insufficient unlocked funds" );
        lockedAmount = lockedAmount.add(amount);
    }

    function unlock(uint amount) public override onlyOwner {
        require(lockedAmount >= amount, "Pool: Insufficient locked funds");
        lockedAmount = lockedAmount.sub(amount);
    }

    function send(address payable to, uint amount) public override onlyOwner {
        require(lockedAmount >= amount, "Pool: Insufficient locked funds");
        lockedAmount -= amount;
        token.transfer(to, amount);
    }
}
