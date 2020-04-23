pragma solidity ^0.6.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/dev/AggregatorInterface.sol";

interface  IUniswapFactory {
    function getExchange(IERC20 token)  external view returns (UniswapExchangeInterface exchange);
}


interface UniswapExchangeInterface {
    // // Address of ERC20 token sold on this exchange
    // function tokenAddress() external view returns (address token);
    // // Address of Uniswap Factory
    // function factoryAddress() external view returns (address factory);
    // // Provide Liquidity
    // function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256);
    // function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) external returns (uint256, uint256);
    // // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    // function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    // function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
    // // Trade ETH to ERC20
    // function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns (uint256  tokens_bought);
    // function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable returns (uint256  eth_sold);
    // function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable returns (uint256  eth_sold);
    // // Trade ERC20 to ETH
    // function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address recipient) external returns (uint256  eth_bought);
    // function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external returns (uint256  tokens_sold);
    // function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external returns (uint256  tokens_sold);
    // // Trade ERC20 to ERC20
    // function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address token_addr) external returns (uint256  tokens_bought);
    // function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_bought);
    // function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address token_addr) external returns (uint256  tokens_sold);
    // function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_sold);
    // // Trade ERC20 to Custom Pool
    // function tokenToExchangeSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address exchange_addr) external returns (uint256  tokens_bought);
    // function tokenToExchangeTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_bought);
    // function tokenToExchangeSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address exchange_addr) external returns (uint256  tokens_sold);
    // function tokenToExchangeTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_sold);
    // // ERC20 comaptibility for liquidity tokens
    // bytes32 public name;
    // bytes32 public symbol;
    // uint256 public decimals;
    // function transfer(address _to, uint256 _value) external returns (bool);
    // function transferFrom(address _from, address _to, uint256 value) external returns (bool);
    // function approve(address _spender, uint256 _value) external returns (bool);
    // function allowance(address _owner, address _spender) external view returns (uint256);
    // function balanceOf(address _owner) external view returns (uint256);
    // function totalSupply() external view returns (uint256);
    // // Never use
    // function setup(address token_addr) external;
}

interface ILiquidityPool {
    event Withdraw(address indexed account, uint amount, uint writeAmount);
    event Provide (address indexed account, uint amount, uint writeAmount);
    function totalBalance() external view returns (uint amount);
    function lock(uint amount) external;
    function unlock(uint amount) external;
    function send(address payable account, uint amount) external;
}

interface IERCLiquidityPool is ILiquidityPool {
    function token() external view returns(IERC20);
}

interface ERC20Incorrect { // for the future
  function balanceOf(address who) external view returns (uint);
  function transfer(address to, uint value) external;
  function allowance(address owner, address spender) external view returns (uint);
  function transferFrom(address from, address to, uint value) external;
  function approve(address spender, uint value) external;

  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);
}

interface SpreadLock {
  function highSpreadLockEnabled() external returns (bool);
}
