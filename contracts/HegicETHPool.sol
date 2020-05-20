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

pragma solidity ^0.6.4;
import "./Interfaces.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic ETH Liquidity Pool
 * @notice Accumulates liquidity in ETH from providers and distributes P&L in ETH
 */
contract HegicETHPool is
    ILiquidityPool,
    Ownable,
    ERC20("Hegic ETH LP Token", "writeETH")
{
    using SafeMath for uint256;
    uint256 public lockedAmount;
    mapping(address => uint256) private lastProvideBlock;

    /*
     * @nonce Send premiums to the liquidity pool
     **/
    receive() external payable {}

    /*
     * @nonce Returns the available amount in ETH for withdrawals
     * @return balance Unlocked amount
     */
    function availableBalance() public view returns (uint256 balance) {
        balance = totalBalance().sub(lockedAmount);
    }

    /*
     * @nonce Returns the ETH total balance provided to the pool
     * @return balance Pool balance
     */
    function totalBalance() public override view returns (uint256 balance) {
        balance = address(this).balance;
    }

    /*
     * @nonce A provider supplies ETH to the pool and receives writeETH tokens
     * @param minMint Low limit tokens that should be received
     * @return mint Received tokens amount
     */
    function provide(uint256 minMint) public payable returns (uint256 mint) {
        mint = provide();
        require(mint >= minMint, "Pool: Mint limit is too large");
    }

    /*
     * @nonce A provider supplies ETH to the pool and receives writeETH tokens
     * @return mint Tokens amount received
     */
    function provide() public payable returns (uint256 mint) {
        lastProvideBlock[msg.sender] = block.number;
        require(!SpreadLock(owner()).highSpreadLockEnabled(), "Pool: Locked");
        if (totalSupply().mul(totalBalance()) == 0) mint = msg.value.mul(1000);
        else
            mint = msg.value.mul(totalSupply()).div(
                totalBalance().sub(msg.value)
            );
        require(mint > 0, "Pool: Amount is too small");
        emit Provide(msg.sender, msg.value, mint);
        _mint(msg.sender, mint);
    }

    /*
     * @nonce Provider burns writeETH and receives ETH back from the pool
     * @param amount ETH amount to receive
     * @param maxBurn Upper limit tokens that can be burned
     * @return burn Tokens amount burnt
     */
    function withdraw(uint256 amount, uint256 maxBurn)
        public
        returns (uint256 burn)
    {
        burn = withdraw(amount);
        require(burn <= maxBurn, "Pool: Burn limit is too small");
    }

    /*
     * @nonce Provider burns writeETH and receives ETH back from the pool
     * @param amount ETH amount to receive
     * @return burn Tokens amount burnt
     */
    function withdraw(uint256 amount) public returns (uint256 burn) {
        require(
            lastProvideBlock[msg.sender] != block.number,
            "Pool: Provide & Withdraw in one block"
        );
        require(
            amount <= availableBalance(),
            "Pool: Insufficient unlocked funds"
        );
        burn = amount.mul(totalSupply()).div(totalBalance());
        require(burn <= balanceOf(msg.sender), "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");
        _burn(msg.sender, burn);
        emit Withdraw(msg.sender, amount, burn);
        msg.sender.transfer(amount);
    }

    /*
     * @nonce Returns a share of the privider in ETH
     * @param account User address
     * @return A share of the provider in ETH
     */
    function shareOf(address account) public view returns (uint256 share) {
        if (totalBalance() > 0)
            share = totalBalance().mul(balanceOf(account)).div(totalSupply());
    }

    /*
     * @nonce calls by HegicCallOptions to lock funds
     * @param amount Funds that should be locked
     */
    function lock(uint256 amount) public override onlyOwner {
        require(
            lockedAmount.add(amount).mul(10).div(totalBalance()) < 8,
            "Pool: Insufficient unlocked funds"
        );
        lockedAmount = lockedAmount.add(amount);
    }

    /*
     * @nonce calls by HegicCallOptions to unlock funds
     * @param amount Funds that should be unlocked
     */
    function unlock(uint256 amount) public override onlyOwner {
        require(lockedAmount >= amount, "Pool: Insufficient locked funds");
        lockedAmount = lockedAmount.sub(amount);
    }

    /*
     * @nonce calls by HegicCallOptions to send funds to the provider after an option is closed
     * @param to Provider
     * @param amount Funds that should be sent
     */
    function send(address payable to, uint256 amount)
        public
        override
        onlyOwner
    {
        require(lockedAmount >= amount, "Pool: Insufficient locked funds");
        lockedAmount = lockedAmount.sub(amount);
        to.transfer(amount);
    }
}
