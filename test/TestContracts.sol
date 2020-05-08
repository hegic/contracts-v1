pragma solidity ^0.6.4;
import "../contracts/HegicCallOptions.sol";
import "../contracts/HegicCallOptions.sol";
// import "@chainlink/contracts/src/v0.6/dev/AggregatorInterface.sol";

// contract PriceAdapter is IPriceProvider{
//   AggregatorInterface ai;
//   constructor(AggregatorInterface _ai) public { ai = _ai; }
//
//   function latestAnswer() override external view returns (uint){
//     return uint(ai.latestAnswer());
//   }
// }

contract Test{
  HegicCallOptions x;
  function main() public {

  }
}

contract FakeExchange is UniswapExchangeInterface {
  AggregatorInterface price;

  uint public spread = 99;

  constructor(AggregatorInterface pp, FakeUSD t) public {
      price = pp;
      token = t;

  }
  receive() external payable {}
  FakeUSD token;

  function getTokenToEthInputPrice(uint256 tokens_sold) override public view returns (uint256 eth_bought){
      eth_bought = tokens_sold * 1e6 / uint(price.latestAnswer()) * spread;
  }

  function getEthToTokenInputPrice(uint256 eth_sold) override public view returns (uint256 tokens_bought){
      tokens_bought = eth_sold * uint(price.latestAnswer()) * spread / 1e10;
  }

  function ethToTokenTransferInput(uint256, uint256, address recipient) override payable public returns (uint256 amount){
      amount = getEthToTokenInputPrice( msg.value );
      token.mint(amount);
      token.transfer(recipient, amount);
  }
  function tokenToEthTransferInput(uint256 tokens_sold, uint256, uint256, address recipient) override external returns (uint256  eth_bought){
      eth_bought = getTokenToEthInputPrice( tokens_sold );
      token.transferFrom(msg.sender, address(this), tokens_sold);
      uint amount = eth_bought;
      if(address(this).balance < amount) amount = address(this).balance;
      address(uint160(recipient)).transfer(amount);
  }

  function withdrow() public {
      msg.sender.transfer(address(this).balance);
  }
}

contract FakeUniswapFactory is IUniswapFactory {
    FakeExchange public exchange;
    constructor(AggregatorInterface pp, FakeUSD baseToken) public {
        exchange = new FakeExchange(pp,baseToken);
    }
    function getExchange(IERC20) override public view returns (UniswapExchangeInterface){
        return exchange;
    }
}

contract FakePriceProvider {
	uint public price;
	constructor(uint p) public {price = p;}
	function latestAnswer() external view returns (uint256){return price;}
}

contract FakeUSD is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    function mint(uint amount) public {_mint(msg.sender, amount);}

    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) override public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) override public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) override public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) override public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) override public returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}

//
// contract MyPool is HegicERCPool {
//     constructor(IERC20 t) public HegicERCPool(t){}
//
//     function info() public view returns (uint balance, uint supply, uint DAIshare, uint DAItotal) {
//         balance = this.balanceOf(msg.sender);
//         supply = totalSupply();
//         DAItotal = this.totalBalance();
//         DAIshare = shareOf(_msgSender());
//     }
// }
