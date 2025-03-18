describe("Scroll Module Tests", function()

  local scroll

  setup(function()
    scroll = require "terminal.scroll"
  end)

  it("should return default scroll region reset sequence", function()
    assert.are.equal("\27[r", scroll.regions())
  end)


  it("should return correct scroll region set sequence", function()
    assert.are.equal("\27[5;10r", scroll.regions(5, 10))
  end)


  it("should return correct sequence for scrolling up by default 1 line", function()
    assert.are.equal("\27[1S", scroll.ups())
  end)


  it("should return correct sequence for scrolling up by 5 lines", function()
    assert.are.equal("\27[5S", scroll.ups(5))
  end)


  it("should return correct sequence for scrolling down by default 1 line", function()
    assert.are.equal("\27[1T", scroll.downs())
  end)


  it("should return correct sequence for scrolling down by 3 lines", function()
    assert.are.equal("\27[3T", scroll.downs(3))
  end)


  it("should return empty string for zero vertical scroll", function()
    assert.are.equal("", scroll.scrolls(0))
  end)


  it("should return correct sequence for positive vertical scroll (down)", function()
    assert.are.equal("\27[3T", scroll.scrolls(3))
  end)


  it("should return correct sequence for negative vertical scroll (up)", function()
    assert.are.equal("\27[2S", scroll.scrolls(-2))
  end)

end)
