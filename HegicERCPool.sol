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
        require(!SpreadLock(owner()).highSpreadLockEnabled(), "Pool: Locked");
        if(totalSupply().mul(totalBalance()) == 0) _mint(msg.sender, amount * 1000);
        else {
          uint mint  = amount.mul(totalSupply()).div(totalBalance());
          require(mint > 0, "Pool: Amount is too small");
          _mint(msg.sender, mint);
        }
        require(
          token.transferFrom(msg.sender, address(this), amount),
          "Insufficient funds"
        );
    }

    function withdraw(uint amount) public {
        require(amount <= availableBalance(), "Pool: Insufficient unlocked funds");
        uint burn = amount.mul(totalSupply()).div(totalBalance());
        require(burn <= balanceOf(msg.sender), "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");
        _burn(msg.sender, burn);
        require(
          token.transfer(msg.sender, amount),
          "Insufficient funds"
        );
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
        require(
          token.transfer(to, amount),
          "Insufficient funds"
        );
    }
}
