# Hegic Protocol V1

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) [![Discord](https://img.shields.io/discord/679629806043660298?color=768AD4&label=Discord&logo=discord&logoColor=768AD4)](https://discordapp.com/channels/679629806043660298/) [![Telegram](https://img.shields.io/badge/chat-on%20Telegram-9cf.svg)](https://t.me/HegicOptions) [![Twitter Follow](https://img.shields.io/twitter/follow/HegicOptions?style=social)](https://twitter.com/HegicOptions)

![alt text](https://i.imgur.com/7zMA5pp.png)


[Hegic](https://www.hegic.co) is an on-chain options trading protocol on [Ethereum](https://github.com/ethereum).

The core of the Hegic Protocol V1 is a system of [Solidity smart contracts](https://github.com/ethereum/solidity). The main parts of the protocol are **options contracts** and **liquidity pools contracts**. Options contracts are *Call Options Contract* and *Put Options Contract*. Liquidity pools contracts are *ETH Pool Contract* and *ERC Pool Contract*.

## Table of Contents

 - [What are Options](#what-are-options)
 - [How Hegic Protocol V1 Works](#how-hegic-protocol-v1-works)
 - [Important Warning](#important-warning)
 - [Contracts](#contracts)
 - [Admin Key](#admin-key)
 - [Documents](#documents)
 - [Maintainer](#maintainer)
 - [Acknolwedgements](#acknolwedgements)
 - [License](#license)

## What are Options

An option is a contract giving the buyer *the right, but not the obligation*, to buy (in the case of a call option contract) or sell (in the case of a put option contract) the underlying asset *at a specific price on or before a certain date*. Traders can use on-chain options for speculation or to hedge their positions. Options are known as *derivatives* because they derive their value from an underlying asset. 

Learn more about options and Hegic Protocol on [GitBook](https://hegic.gitbook.io/start/).

## How Hegic Protocol V1 Works

HegicCallOptions and HegicPutOptions are options contracts. These contracts calculate `fees` (options prices), `create` new options, `exercise` options contracts on behalf of the holders and `exchange` holders' assets using [the Uniswap Protocol](https://github.com/Uniswap) for sending liquidity back to the pool during the process of exercising.

HegicETHPool and HegicERCPool are liquidity pools contracts. These non-custodial contracts accumulate liquidity from providers (writers). Pooled liquidity is used for selling (writing) options contracts to the buyers (holders). After a liquidity provider calls the `provide` method, they send ETH / [ERC-20 tokens](https://eips.ethereum.org/EIPS/eip-20) to the liquidity pool contract and receive writeETH / writeERC (ERC-20) tokens to their address. To leave the pool a liqudity provider calls the `withdraw` method, burns their writeETH / writeERC tokens and receives ETH / ERC-20 tokens to their address.

------------------------------

ETH Call Options are created and exercised via **HegicCallOptions** and **HegicETHPool** contracts.

**ETH Call Option is an on-chain contract that gives a holder a right to swap their [DAI stablecoins](https://github.com/makerdao/dss) for [ETH](https://ethereum.org/eth/) at a fixed price during a certain period.** To activate an ETH Call Option a holder chooses the `period`, `amount` and `strike`  for their option contract. After paying `fees`, the `lock` method of the HegicETHPool contract locks ETH `strikeAmount` on the pool contract. If a holder intends to swap their DAI for ETH during a fixed period that they have paid for, they call the `exercise` method. The HegicETHPool contract will receive holder's DAI and will send the amount of ETH that was locked on the contract for this particular holder. Calling the `exchange` method of the HegicETHPool contract will automatically swap DAI received from the option holder for ETH at the market price using [the Uniswap Protocol's ETH-DAI pool](https://uniswap.info/token/0x6b175474e89094c44da98b954eedeac495271d0f). After the swap, ETH is sent back to the HegicETHPool contract.

------------------------------

ETH Put Options are created and exercised via **HegicPutOptions** and **HegicERCPool** contracts.

**ETH Put Option is an on-chain contract that gives a holder a right to swap their [ETH](https://ethereum.org/eth/) for [DAI stablecoins](https://github.com/makerdao/dss) at a fixed price during a certain period.** To activate an ETH Put Option a holder chooses the `period`, `amount` and `strike` for their option contract. After paying `fees`, the `lock` method of the HegicERCPool contract locks DAI `amount` on the pool contract. If a holder intends to swap their ETH for DAI during a fixed period that they have paid for, they call the `exercise` method. The HegicERCPool contract will receive holder's ETH and will send the amount of DAI that was locked on the contract for this particular holder. Calling the `exchange` method of the HegicERCPool contract will automatically swap ETH received from the option holder for DAI at the market price using [the Uniswap Protocol's ETH-DAI pool](https://uniswap.info/token/0x6b175474e89094c44da98b954eedeac495271d0f). After the swap, DAI is sent back to the HegicERCPool contract.

## Important Warning

**Hegic Protocol V1 has not been audited yet. You can lose up to 100% of your funds that you provide to the liquidity pools contracts. There is a technical risk that the Hegic Protocol V1 contracts can be hacked in the future. Never provide more funds to the liquidity pools contracts than you can afford to lose. Always DYOR.**

## Contracts

|Contract|Description|Mainnet Address|
|---|---|---|
|[`HegicCallOptions`](https://github.com/hegic/hegic-contracts-v1/blob/master/HegicCallOptions.sol)|ETH Call Options|[0x1c4823024627c978f758a4f2f67d7eae94838b04](https://etherscan.io/address/0x1c4823024627c978f758a4f2f67d7eae94838b04)|
|[`HegicPutOptions`](https://github.com/hegic/hegic-contracts-v1/blob/master/HegicPutOptions.sol)|ETH Put Options|[0x7e8f1650Cc4C2964D00250e2bC5c84a409348152](https://etherscan.io/address/0x7e8f1650Cc4C2964D00250e2bC5c84a409348152)|
|[`HegicETHPool`](https://github.com/hegic/hegic-contracts-v1/blob/master/HegicETHPool.sol)|ETH Liquidity Pool|[0x476ae277b5c5dc199F82C681989b8021fD9d8D50](https://etherscan.io/address/0x476ae277b5c5dc199F82C681989b8021fD9d8D50)|
|[`HegicERCPool`](https://github.com/hegic/hegic-contracts-v1/blob/master/HegicERCPool.sol)|ERC Liquidity Pool|[0xA2C77163B1a00A153A224F3f0b6b0e5cd19524ed](https://etherscan.io/address/0xA2C77163B1a00A153A224F3f0b6b0e5cd19524ed)|
|`Aggregator`|ETH/USD Price Feed|[0xF79D6aFBb6dA890132F9D7c355e3015f15F3406F](https://etherscan.io/address/0xF79D6aFBb6dA890132F9D7c355e3015f15F3406F)|


## Admin Key

Hegic Protocol V1 contracts admin key holder CAN:

* call `setImpliedVolRate` function to change the Implied Volatility proxy that influences the `fees`

* call `setMaxSpread` function to change the maximum spread for the swap on the Uniswap Protocol


**Hegic Protocol V1 contracts admin key holder CAN'T:**

* call `withdraw` function (can't withdraw users' funds from the pools contracts)

* call `lock` function (can't lock funds on the liquidity pools contracts)

* call `unlock` function (can't unlock funds on unexercised active contracts)

* call `transfer` function (can't send users' writeETH / writeERC tokens)

* call `exercise` function (can't exercise  users' active options contracts)


## Documents

* Hegic: On-chain Options Trading Protocol on Ethereum Powered by Hedge Contracts and Liquidity Pools: https://ipfs.io/ipfs/QmWy8x6vEunH4gD2gWT4Bt4bBwWX2KAEUov46tCLvMRcME by Molly Wintermute.

* Hegic Protocol FAQ, guides and educational information about options on GitBook: https://hegic.gitbook.io/start

## Maintainer

[Molly Wintermute](https://github.com/0mllwntrmt3). Contact: molly.wintermute@protonmail.com | https://keybase.io/mollywintermute

## Acknolwedgements

[Sam Sun](https://github.com/samczsun), [Lev Livnev](https://github.com/livnev), [Dan Elitzer](https://github.com/delitzer), [Jon Itzler](https://github.com/itzler) helped make Hegic Protocol V1 better. Thank you.

## License

The Hegic Protocol V1 is under [the GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0).
