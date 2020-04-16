pragma solidity ^0.6.4;
import "./Interfaces.sol";

contract HegicETHPool is ILiquidityPool, Ownable, ERC20("Hegic ETH LP Token", "writeETH"){
    using SafeMath for uint256;
    uint public lockedAmount;
    receive() external payable {}

    function availableBalance() public view returns (uint balance) {balance = totalBalance().sub(lockedAmount);}
    function totalBalance() public override view returns (uint balance) { balance = address(this).balance;}

    function provide(uint minMint) public payable returns (uint mint) {
        mint = provide();
        require(mint >= minMint, "Pool: Mint limit is too large");
    }

    function provide() public payable returns (uint mint) {
        require(!SpreadLock(owner()).highSpreadLockEnabled(), "Pool: Locked");
        if(totalSupply().mul(totalBalance()) == 0) _mint(msg.sender, msg.value.mul(1000));
        else {
          mint  = msg.value.mul(totalSupply()).div(totalBalance());
          require(mint > 0, "Pool: Amount is too small");
          _mint(msg.sender, mint);
        }
    }

    function withdraw(uint amount, uint maxBurn) public returns (uint burn) {
      burn = withdraw(amount);
      require(burn <= maxBurn, "Pool: Burn limit is too small");
    }

    function withdraw(uint amount) public returns (uint burn) {
        require(amount <= availableBalance(), "Pool: Insufficient unlocked funds");
        burn = amount.mul(totalSupply()).div(totalBalance());
        require(burn <= balanceOf(msg.sender), "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");
        _burn(msg.sender, burn);
        msg.sender.transfer(amount);
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
        to.transfer(amount);
    }
}
