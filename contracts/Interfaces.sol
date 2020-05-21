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

pragma solidity ^0.6.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/dev/AggregatorInterface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";


interface ILiquidityPool {
    event Withdraw(
        address indexed account,
        uint256 amount,
        uint256 writeAmount
    );
    event Provide(address indexed account, uint256 amount, uint256 writeAmount);

    function totalBalance() external view returns (uint256 amount);

    function lock(uint256 amount) external;

    function unlock(uint256 amount) external;

    function unlockPremium(uint256 amount) external;

    function send(address payable account, uint256 amount) external;

    function setLockupPeriod(uint value) external;
}


interface IERCLiquidityPool is ILiquidityPool {
    function token() external view returns (IERC20);

    function sendPremium(uint256 amount) external;
}


interface IETHLiquidityPool is ILiquidityPool {
    function sendPremium() external payable;
}


interface ERC20Incorrect {
    // for the future
    function balanceOf(address who) external view returns (uint256);

    function transfer(address to, uint256 value) external;

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;

    function approve(address spender, uint256 value) external;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
}
