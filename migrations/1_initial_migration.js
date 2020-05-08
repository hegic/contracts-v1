const BN = web3.utils.BN
const Exchange = artifacts.require("FakeUniswapFactory");
const StableCoin = artifacts.require("FakeUSD");
const PriceProvider = artifacts.require("FakePriceProvider");
const CallHedge = artifacts.require('HegicCallOptions')
const PutHedge = artifacts.require('HegicPutOptions')
const ETHPool = artifacts.require('HegicETHPool')
const ERCPool = artifacts.require('HegicERCPool')

const priceProviderSettings = { currentAnswer: new BN(200e8) }

module.exports = async function(deployer, network) {
  try {
    if (network == 'development' || network == 'develop') {
      await deployer.deploy(StableCoin)
      await deployer.deploy(PriceProvider, priceProviderSettings.currentAnswer);
      await deployer.deploy(Exchange, PriceProvider.address, StableCoin.address);
      await deployer.deploy(PutHedge,  StableCoin.address, PriceProvider.address, Exchange.address);
      await deployer.deploy(CallHedge, StableCoin.address, PriceProvider.address, Exchange.address);
    } else if(network == 'main') {
      const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'
      const ChainLink = '0xF79D6aFBb6dA890132F9D7c355e3015f15F3406F'
      const Uniswap = '0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95'
      await deployer.deploy(PutHedge,  DAI, ChainLink, Uniswap)
      await deployer.deploy(CallHedge, DAI, ChainLink, Uniswap)
    } else if(network == 'ropsten') {
      // await deployer.deploy(StableCoin)
      var DAI = '0x2fD2Db40bcb5740808E59Ff2458bf34928bbc552'
      var CHL = '0x8468b2bDCE073A157E560AA4D9CcF6dB1DB98507'
      var UNS = '0xddB1E24A7F58189c81e95A7eC474b9fe0e77A026'
      var EXC = '0xa6a3593Ba27Ca1791a1F119dd8E92259544f57e9'
      var PUT = '0xdfA6c5d073fB52AE840A58DC0419932802010D5e'
      var CLL = '0x74c29199Dce051b8D39f4FAFa36187737fC41f6E'
      var CPL = '0x0c4Ba93DB9F867eF6822Fcbd69fbed1EFAb785b1'
      var PPL = '0x29D0dbAc1D7e093a3BEd42c216F5d31BD5fb44f7'
    } else if(network == 'rinkeby') {
      const DAI = '0x2448eE2641d78CC42D7AD76498917359D961A783'
      const UNS = '0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36'
      const EXC = '0x77dB9C915809e7BE439D2AB21032B1b8B58F6891'
      const CHL = '0x0bF4e7bf3e1f6D6Dc29AA516A33134985cC3A5aA'
      const HGC = '0x342FeF4aa67E0b67f248867099Ce6F7B7E3c9D43'
      const ETP = '0x15d263f99D025A4Bfa6FA01c308556f90a9D5aB3'
    } else throw `unsupported network ${network}`
  } catch (err) {console.error(err)}
};
