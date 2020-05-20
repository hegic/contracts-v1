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
import "./Interfaces.sol";


/**
 * @author 0mllwntrmt3
 * @title Hegic DAI Liquidity Pool
 * @notice Accumulates liquidity in DAI from providers and distributes P&L in DAI
 */
contract HegicERCPool is
    IERCLiquidityPool,
    Ownable,
    ERC20("Hegic DAI LP Token", "writeDAI")
{
    using SafeMath for uint256;
    uint256 public lockedAmount;
    mapping(address => uint256) private lastProvideBlock;
    IERC20 public override token;

    /*
     * @return _token DAI Address
     */
    constructor(IERC20 _token) public {
        token = _token;
    }

    /*
     * @nonce Returns the available amount in DAI for withdrawals
     * @return balance Unlocked amount
     */
    function availableBalance() public view returns (uint256 balance) {
        balance = totalBalance().sub(lockedAmount);
    }

    /*
     * @nonce Returns the DAI total balance provided to the pool
     * @return balance Pool balance
     */
    function totalBalance() public override view returns (uint256 balance) {
        balance = token.balanceOf(address(this));
    }

    /*
     * @nonce A provider supplies DAI to the pool and receives writeDAI tokens
     * @param amount Amount provided
     * @param minMint Low limit tokens that should be received
     * @return mint Received tokens amount
     */
    function provide(uint256 amount, uint256 minMint)
        public
        returns (uint256 mint)
    {
        mint = provide(amount);
        require(mint >= minMint, "Pool: Mint limit is too large");
    }

    /*
     * @nonce A provider supplies DAI to the pool and receives writeDAI tokens
     * @param amount Provided tokens
     * @return mint Tokens amount received
     */
    function provide(uint256 amount) public returns (uint256 mint) {
        lastProvideBlock[msg.sender] = block.number;
        require(!SpreadLock(owner()).highSpreadLockEnabled(), "Pool: Locked");
        if (totalSupply().mul(totalBalance()) == 0) mint = amount.mul(1000);
        else mint = amount.mul(totalSupply()).div(totalBalance());

        require(mint > 0, "Pool: Amount is too small");
        emit Provide(msg.sender, amount, mint);
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Insufficient funds"
        );
        _mint(msg.sender, mint);
    }

    /*
     * @nonce Provider burns writeDAI and receives DAI back from the pool
     * @param amount DAI amount to receive
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
     * @nonce Provider burns writeDAI and receives DAI back from the pool
     * @param amount DAI amount to receive
     * @return mint Tokens amount burnt
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
        require(token.transfer(msg.sender, amount), "Insufficient funds");
    }

    /*
     * @nonce Returns a share of the provider in DAI
     * @param account User address
     * @return A share of the provider in DAI
     */
    function shareOf(address user) public view returns (uint256 share) {
        if (totalBalance() > 0)
            share = totalBalance().mul(balanceOf(user)).div(totalSupply());
    }

    /*
     * @nonce calls by HegicPutOptions to lock funds
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
     * @nonce calls by HegicPutOptions to unlock funds
     * @param amount Funds that should be unlocked
     */
    function unlock(uint256 amount) public override onlyOwner {
        require(lockedAmount >= amount, "Pool: Insufficient locked funds");
        lockedAmount = lockedAmount.sub(amount);
    }

    /*
     * @nonce calls by HegicPutOptions to send funds to the provider after an option is closed
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
        require(token.transfer(to, amount), "Insufficient funds");
    }
}
