describe("Spec helpers", function()

  local helpers

  setup(function()
    helpers = require("spec.helpers")
  end)



  it("removes terminal and system from package.loaded", function()
    helpers.load()
    assert.is_not_nil(package.loaded["terminal"])
    helpers.unload()
    assert.is_nil(package.loaded["terminal"])
    assert.is_nil(package.loaded["system"])
  end)


  it("allows load() to return terminal again after unload", function()
    helpers.unload()
    local _ = helpers.load()
    assert.is_not_nil(package.loaded["terminal"])
    helpers.unload()
    assert.is_nil(package.loaded["terminal"])
    local t2 = helpers.load()
    assert.is_table(t2)
    assert.is_not_nil(package.loaded["terminal"])
  end)


  it("returns terminal module with expected API after unload then load", function()
    helpers.unload()
    local terminal = helpers.load()
    assert.is_table(terminal.input)
  end)


  it("returns valid terminal table on second load after unload", function()
    helpers.unload()
    local t1 = helpers.load()
    helpers.unload()
    local t2 = helpers.load()
    assert.is_table(t2)
    assert.is_table(t2.utils)
    assert.is_table(t2.input)
    assert.not_equal(t1, t2)
  end)

end)
