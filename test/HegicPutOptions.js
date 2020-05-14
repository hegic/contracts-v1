const {getContracts, timeTravel, toWei} = require("./utils/utils.js")
const BN = web3.utils.BN

contract("HegicPutOptions", ([user1, user2, user3]) => {
  const contracts = getContracts()

  it("The first account should be the contract owner", async () => {
    const {PUT} = await contracts
    assert.equal(
      await PUT.owner.call(),
      user1,
      "The first account isn't the contract owner"
    )
  })

  it("Should be the owner of the pool contract", async () => {
    const {PUT, ERCPool} = await contracts
    assert.equal(
      await ERCPool.owner(),
      PUT.address,
      "Isn't the owner of the pool"
    )
  })

  it("Should create an option", async () => {
    const {PUT, ERCPool, DAI} = await contracts
    const [period, amount, price] = [24 * 3600, toWei("0.1"), "18000000000"]
    const poolAmount = toWei("10000")

    await DAI.mint(poolAmount)
    await DAI.approve(ERCPool.address, poolAmount)
    await ERCPool.provide(poolAmount)

    const {total, settlementFee} = await PUT.fees(period, amount, price)
    const createEvent = await PUT.create(period, amount, price, {
      value: total,
      from: user1,
    })
      .then((x) => x.logs.find((x) => x.event == "Create"))
      .then((x) => (x ? x.args : null))
    assert.isNotNull(createEvent, "'Create' event has not been initialized")
    assert(
      createEvent.id.eq(new BN(0)),
      "The first option's ID isn't equal to 0"
    )
    assert.equal(createEvent.account, user1, "Wrong account")
    assert(total.eq(createEvent.totalFee), "Wrong totalFee value")
    assert(
      settlementFee.eq(createEvent.settlementFee),
      "Wrong settlementFee value"
    )
    assert(
      new BN(amount).div(new BN(100)).eq(createEvent.settlementFee),
      "Wrong settlementFee value"
    )
  })

  it("Should create other options", async () => {
    const {PUT} = await contracts
    const [period, amount, price] = [24 * 3600, toWei("0.1"), "18000000000"]
    const {total: value} = await PUT.fees(period, amount, price)
    await Promise.all([
      PUT.create(period, amount, price, {value, from: user2}),
      PUT.create(period, amount, price, {value, from: user3}),
    ])
  })

  it("Shouldn't exercise a new option", async () => {
    const {PUT} = await contracts
    const {amount} = await PUT.options(0)
    await PUT.exercise(0, {value: amount}).then(
      () => assert.fail("Exercising a put option should be canceled"),
      (x) => {
        assert.equal(
          x.reason,
          "Option has not been activated yet",
          "Wrong error reason"
        )
      }
    )
  })

  it("Should exercise an option after 15 minutes", async () => {
    const {PUT, DAI} = await contracts
    await timeTravel(15 * 60)
    const {amount} = await PUT.options(0)
    const exersizeEvent = await PUT.exercise(0, {value: amount})
      .then((x) => x.logs.find((log) => log.event == "Exercise"))
      .then((x) => (x ? x.args : null))
      .catch((x) => assert.fail(x.reason))
    assert.isNotNull(exersizeEvent, "'Exercise' event has not been initialized")
    assert.equal(
      exersizeEvent.id.toNumber(),
      0,
      "Wrong option ID has been initialized"
    )
  })

  it("Shouldn't exercise other options", async () => {
    const {PUT, DAI} = await contracts
    const {amount} = await PUT.options(1)
    await PUT.exercise(1, {from: user1}).then(
      () => assert.fail("Exercising a put option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Wrong msg.sender", "Wrong error reason")
      }
    )
  })

  it("Shouldn't unlock an active option", async () => {
    const {PUT} = await contracts
    await PUT.unlock(1).then(
      () => assert.fail("Exercising a put option should be canceled"),
      (x) => {
        assert.equal(
          x.reason,
          "Option has not expired yet",
          "Wrong error reason"
        )
      }
    )
  })

  it("Shouldn't exercise an expired option", async () => {
    const {PUT, DAI} = await contracts
    const {amount} = await PUT.options(1)
    await timeTravel(24 * 3600)
    await PUT.exercise(1, {from: user2, value: amount}).then(
      () => assert.fail("Exercising a put option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Option has expired", "Wrong error reason")
      }
    )
  })

  it("Shouldn't unlock an exercised option", async () => {
    const {PUT} = await contracts
    await PUT.unlock(0).then(
      () => assert.fail("Exercising a put option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Option is not active", "Wrong error reason")
      }
    )
  })

  it("Should unlock expired options", async () => {
    const {PUT} = await contracts
    const EXPIRED = new BN(2)
    const expected = [1, 2]

    const actual = await PUT.unlockAll(expected)
      .then((x) => x.logs.filter((x) => x.event == "Expire"))
      .then((x) => x.map((x) => x.args.id.toNumber()))

    assert.deepEqual(expected, actual, "Wrong optionIDs has been initialized")
    for (const id of expected) {
      const option = await PUT.options(id)
      assert(option.state.eq(EXPIRED), `option ${id} is not expired`)
    }
  })
})
