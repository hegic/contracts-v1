const PUTContract = artifacts.require("HegicPutOptions")
const CALLContract = artifacts.require("HegicCallOptions")
const ERCPoolContract = artifacts.require("HegicERCPool")
const ETHPoolContract = artifacts.require("HegicETHPool")
const DAIContract = artifacts.require("FakeUSD")
const PriceContract = artifacts.require("FakePriceProvider")
const BN = web3.utils.BN


const send = (method, params = []) =>
  new Promise((done) =>
    web3.currentProvider.send({id: 0, jsonrpc: "2.0", method, params}, done)
  )
const getContracts = async () => {
  const [PUT, CALL, DAI, PriceProvider] = await Promise.all([
    PUTContract.deployed(),
    CALLContract.deployed(),
    DAIContract.deployed(),
    PriceContract.deployed(),
  ])
  const [ERCPool, ETHPool] = await Promise.all([
    PUT.pool.call().then((address) => ERCPoolContract.at(address)),
    CALL.pool.call().then((address) => ETHPoolContract.at(address)),
  ])
  return {PUT, CALL, DAI, ETHPool, ERCPool, PriceProvider}
}

const timeTravel = async (seconds) => {
  await send("evm_increaseTime", [seconds])
  await send("evm_mine")
}

module.exports = {
  getContracts,
  timeTravel,
  toWei: (value) => web3.utils.toWei(value.toString(), "ether"),
  MAX_INTEGER: new BN(2).pow(new BN(256)).sub(new BN(1)),
}
