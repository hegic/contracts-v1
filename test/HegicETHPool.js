const {getContracts, toWei, timeTravel, MAX_INTEGER} = require("./utils/utils.js")
const BN = web3.utils.BN

// const firstProvide  = new BN( '1000000000000000000' )
// const secondProvide = new BN( '1000000000000000000' )
// const thirdProvide  = new BN( '3000000000000000000' )
// const thirdWithdraw = new BN(  '500000000000000005' )
// const profit = new BN( '100' )

const firstProvide = new BN(toWei(Math.random()))
const secondProvide = new BN(toWei(Math.random()))
const thirdProvide = new BN(toWei(Math.random()))
const firstWithdraw = firstProvide
const profit = new BN(toWei(Math.random())).div(new BN(1000))

contract("HegicETHPool", ([user1, user2, user3]) => {
  const contracts = getContracts()

  it("Should mint tokens for the first provider correctly", async () => {
    const {ETHPool} = await contracts
    await ETHPool.provide(0, {value: firstProvide, from: user1})
    assert(
      await ETHPool.shareOf(user1).then((x) => x.eq(firstProvide)),
      "Wrong amount"
    )
  })

  it("Should mint tokens for the second provider correctly", async () => {
    const {ETHPool} = await contracts
    await ETHPool.provide(0, {value: secondProvide, from: user2})
    assert(
      await ETHPool.shareOf(user2).then((x) => x.eq(secondProvide)),
      "Wrong amount"
    )
  })

  it("Should distribute the profits correctly", async () => {
    const {ETHPool} = await contracts
    const value = profit
    const [startShare1, startShare2] = await Promise.all([
      ETHPool.shareOf(user1),
      ETHPool.shareOf(user2),
    ])

    const expected1 = value
      .mul(startShare1)
      .div(startShare1.add(startShare2))
      .add(startShare1)
    const expected2 = value
      .mul(startShare2)
      .div(startShare1.add(startShare2))
      .add(startShare2)

    await ETHPool.sendTransaction({value, from: user3})
    const [res1, res2] = await Promise.all([
      ETHPool.shareOf(user1).then((x) => x.eq(expected1)),
      ETHPool.shareOf(user2).then((x) => x.eq(expected2)),
    ])
    assert(res1 && res2, "The profits value isn't correct")
  })

  it("Should mint tokens for the third provider correctly", async () => {
    const {ETHPool} = await contracts
    const value = thirdProvide
    const [startShare1, startShare2] = await Promise.all([
      ETHPool.shareOf(user1),
      ETHPool.shareOf(user2),
    ])
    await ETHPool.provide(0, {value, from: user3})
    assert.isAtLeast(
      await ETHPool.shareOf(user3).then((x) => x.sub(value).toNumber()),
      -1,
      "The third provider has lost funds"
    )
    assert(
      await ETHPool.shareOf(user1).then((x) => x.eq(startShare1)),
      "The first provider has an incorrect share"
    )
    assert(
      await ETHPool.shareOf(user2).then((x) => x.eq(startShare2)),
      "The second provider has an incorrect share"
    )
  })

  it("Should burn the first provider's tokens correctly", async () => {
    const {ETHPool} = await contracts
    const value = firstWithdraw
    const startBalance = await web3.eth.getBalance(user1).then((x) => new BN(x))

    const [startShare1, startShare2, startShare3] = await Promise.all([
      ETHPool.shareOf(user1),
      ETHPool.shareOf(user2),
      ETHPool.shareOf(user3),
    ])

    await timeTravel(14 * 24 * 3600 + 1)
    const gasPrice = await web3.eth.getGasPrice().then((x) => new BN(x))
    const transactionFee = await ETHPool.withdraw(value, MAX_INTEGER)
      .then((x) => new BN(x.receipt.gasUsed))
      .then((x) => x.mul(gasPrice))
    const endBalance = await web3.eth.getBalance(user1).then((x) => new BN(x))
    const balanceDelta = endBalance.add(transactionFee).sub(startBalance)

    const [share1, share2, share3] = await Promise.all([
      ETHPool.shareOf(user1),
      ETHPool.shareOf(user2),
      ETHPool.shareOf(user3),
    ])
    assert.isAtLeast(
      share2.sub(startShare2).toNumber(),
      -1,
      "The second user has lost funds"
    )
    assert.isAtLeast(
      share3.sub(startShare3).toNumber(),
      -1,
      "The third user has lost funds"
    )
    assert(
      balanceDelta.eq(value),
      "The first provider has received an incorrect amount"
    )
    assert.equal(
      share1.add(value).sub(startShare1),
      0,
      "The first provider has an incorrect share"
    )
  })
})
