const {getContracts, timeTravel, toWei} = require("./utils/utils.js")
const BN = web3.utils.BN

contract("HegicCallOptions", ([user1, user2, user3]) => {
  const contracts = getContracts()

  it("The first account should be the contract owner", async () => {
    const {CALL} = await contracts
    assert.equal(
      await CALL.owner.call(),
      user1,
      "The first account isn't the contract owner"
    )
  })

  it("Should be the owner of the pool contract", async () => {
    const {CALL, ETHPool} = await contracts
    assert.equal(
      await ETHPool.owner(),
      CALL.address,
      "Isn't the owner of the pool"
    )
  })

  it("Should create an option", async () => {
    const {CALL, ETHPool} = await contracts
    await ETHPool.provide(0, {value: "1000000000000000000", from: user3})
    const [period, amount, price] = [24 * 3600, toWei("0.1"), "18000000000"]
    const [total, settlementFee] = await CALL.fees(
      period,
      amount,
      price
    ).then((x) => [x.total, x.settlementFee])
    const createEvent = await CALL.create(period, amount, price, {
      value: total,
      from: user1,
    })
      .then((x) => x.logs.find((x) => x.event == "Create"))
      .then((x) => (x ? x.args : null))
    assert.isNotNull(createEvent, "'Create' event has not been initialized")
    assert.equal(createEvent.id, 0, "The first option's ID isn't equal to 0")
    assert.equal(createEvent.account, user1, "Wrong account")
    assert(total.eq(createEvent.totalFee), "Wrong premium value")
    assert(
      new BN(settlementFee).eq(createEvent.settlementFee),
      "Wrong settlementFee value"
    )
    assert(
      new BN(amount).div(new BN(100)).eq(createEvent.settlementFee),
      "Wrong settlementFee value"
    )
  })

  it("Should create other options", async () => {
    const {CALL, ETHPool} = await contracts
    const [period, amount, price] = [24 * 3600, toWei("0.1"), "18000000000"]
    const value = await CALL.fees(period, amount, price).then((x) => x.total)
    await Promise.all([
      CALL.create(period, amount, price, {value, from: user2}),
      CALL.create(period, amount, price, {value, from: user3}),
    ])
  })

  it("Shouldn't exercise a new option", async () => {
    const {CALL} = await contracts
    await CALL.exercise(0).then(
      () => assert.fail("Exercising a call option should be canceled"),
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
    const {CALL, DAI} = await contracts
    await timeTravel(15 * 60)
    const {strikeAmount} = await CALL.options(0)
    await DAI.mint(strikeAmount)
    await DAI.approve(CALL.address, strikeAmount, {from: user2})
    const exersizeEvent = await CALL.exercise(0)
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
    const {CALL, DAI} = await contracts
    const {strikeAmount} = await CALL.options(1)
    await DAI.mint(strikeAmount)
    await DAI.approve(CALL.address, strikeAmount, {from: user2})
    await CALL.exercise(1, {from: user1}).then(
      () => assert.fail("Exercising a call option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Wrong msg.sender", "Wrong error reason")
      }
    )
  })

  it("Shouldn't unlock an active option", async () => {
    const {CALL} = await contracts
    await CALL.unlock(1).then(
      () => assert.fail("Exercising a call option should be canceled"),
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
    const {CALL, DAI} = await contracts
    const {strikeAmount} = await CALL.options(1)
    await DAI.mint(strikeAmount, {from: user2})
    await DAI.approve(CALL.address, strikeAmount, {from: user2})
    await timeTravel(24 * 3600)
    await CALL.exercise(1, {from: user2}).then(
      () => assert.fail("Exercising a call option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Option has expired", "Wrong error reason")
      }
    )
  })

  it("Shouldn't unlock an exercised option", async () => {
    const {CALL} = await contracts
    await CALL.unlock(0).then(
      () => assert.fail("Exercising a call option should be canceled"),
      (x) => {
        assert.equal(x.reason, "Option is not active", "Wrong error reason")
      }
    )
  })

  it("Should unlock expired options", async () => {
    const {CALL} = await contracts
    const EXPIRED = new BN(2)
    const expected = [1, 2]

    const actual = await CALL.unlockAll(expected)
      .then((x) => x.logs.filter((x) => x.event == "Expire"))
      .then((x) => x.map((x) => x.args.id.toNumber()))

    assert.deepEqual(expected, actual, "Wrong optionIDs has been initialized")
    for (const id of expected) {
      const option = await CALL.options(id)
      assert(option.state.eq(EXPIRED), `option ${id} is not expired`)
    }
  })
})
