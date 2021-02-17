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
import "./Interfaces.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic ETH Liquidity Pool
 * @notice Accumulates liquidity in ETH from LPs and distributes P&L in ETH
 */
contract HegicETHPool is
    IETHLiquidityPool,
    Ownable,
    ERC20("Hegic ETH LP Token", "writeETH")
{
    using SafeMath for uint256;
    uint256 public lockupPeriod = 2 weeks;
    uint256 public lockedAmount;
    uint256 public lockedPremium;
    mapping(address => uint256) private lastProvideTimestamp;

    /*
     * @nonce Sends premiums to the liquidity pool
     **/
    receive() external payable {}

    /**
     * @notice Used for changing the lockup period
     * @param value New period value
     */
    function setLockupPeriod(uint256 value) external override onlyOwner {
        require(value <= 60 days, "Lockup period is too large");
        lockupPeriod = value;
    }

    /*
     * @nonce A provider supplies ETH to the pool and receives writeETH tokens
     * @param minMint Minimum amount of tokens that should be received by a provider.
                      Calling the provide function will require the minimum amount of tokens to be minted.
                      The actual amount that will be minted could vary but can only be higher (not lower) than the minimum value.
     * @return mint Amount of tokens to be received
     */
    function provide(uint256 minMint) external payable returns (uint256 mint) {
        lastProvideTimestamp[msg.sender] = now;
        uint256 supply = totalSupply();
        uint256 balance = totalBalance();
        if (supply > 0 && balance > 0)
            mint = msg.value.mul(supply).div(balance.sub(msg.value));
        else mint = msg.value.mul(1000);

        require(mint >= minMint, "Pool: Mint limit is too large");
        require(mint > 0, "Pool: Amount is too small");

        _mint(msg.sender, mint);
        emit Provide(msg.sender, msg.value, mint);
    }

    /*
     * @nonce Provider burns writeETH and receives ETH from the pool
     * @param amount Amount of ETH to receive
     * @return burn Amount of tokens to be burnt
     */
    function withdraw(uint256 amount, uint256 maxBurn)
        external
        returns (uint256 burn)
    {
        require(
            lastProvideTimestamp[msg.sender].add(lockupPeriod) <= now,
            "Pool: Withdrawal is locked up"
        );
        require(
            amount <= availableBalance(),
            "Pool Error: Not enough funds on the pool contract. Please lower the amount."
        );
        burn = amount.mul(totalSupply()).div(totalBalance());

        require(burn <= maxBurn, "Pool: Burn limit is too small");
        require(burn <= balanceOf(msg.sender), "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");

        _burn(msg.sender, burn);
        emit Withdraw(msg.sender, amount, burn);
        msg.sender.transfer(amount);
    }

    /*
     * @nonce calls by HegicCallOptions to lock the funds
     * @param amount Amount of funds that should be locked in an option
     */
    function lock(uint256 amount) external override onlyOwner {
        require(
            lockedAmount.add(amount).mul(10).div(totalBalance()) < 8,
            "Pool Error: You are trying to unlock more funds than have been locked for your contract. Please lower the amount."
        );
        lockedAmount = lockedAmount.add(amount);
    }

    /*
     * @nonce calls by HegicCallOptions to unlock the funds
     * @param amount Amount of funds that should be unlocked in an expired option
     */
    function unlock(uint256 amount) external override onlyOwner {
        require(
            lockedAmount >= amount,
            "Pool Error: You are trying to unlock more funds than have been locked for your contract. Please lower the amount."
        );
        lockedAmount = lockedAmount.sub(amount);
    }

    /*
     * @nonce calls by HegicPutOptions to lock the premiums
     * @param amount Amount of premiums that should be locked
     */
    function sendPremium() external override payable onlyOwner {
        lockedPremium = lockedPremium.add(msg.value);
    }

    /*
     * @nonce calls by HegicPutOptions to unlock the premiums after an option's expiraton
     * @param amount Amount of premiums that should be unlocked
     */
    function unlockPremium(uint256 amount) external override onlyOwner {
        require(
            lockedPremium >= amount,
            "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount."
        );
        lockedPremium = lockedPremium.sub(amount);
    }

    /*
     * @nonce calls by HegicCallOptions to send funds to liquidity providers after an option's expiration
     * @param to Provider
     * @param amount Funds that should be sent
     */
    function send(address payable to, uint256 amount)
        external
        override
        onlyOwner
    {
        require(to != address(0));
        require(
            lockedAmount >= amount,
            "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount."
        );
        to.transfer(amount);
    }

    /*
     * @nonce Returns provider's share in ETH
     * @param account Provider's address
     * @return Provider's share in ETH
     */
    function shareOf(address account) external view returns (uint256 share) {
        if (totalSupply() > 0)
            share = totalBalance().mul(balanceOf(account)).div(totalSupply());
        else share = 0;
    }

    /*
     * @nonce Returns the amount of ETH available for withdrawals
     * @return balance Unlocked amount
     */
    function availableBalance() public view returns (uint256 balance) {
        return totalBalance().sub(lockedAmount);
    }

    /*
     * @nonce Returns the total balance of ETH provided to the pool
     * @return balance Pool balance
     */
    function totalBalance() public override view returns (uint256 balance) {
        return address(this).balance.sub(lockedPremium);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal override {
        require(
            lastProvideTimestamp[from].add(lockupPeriod) <= now,
            "Pool: Withdrawal is locked up"
        );
    }
}
