describe("Scroll Module Tests", function()

  local scroll

  setup(function()
    scroll = require "terminal.scroll"
  end)



  it("should return default scroll region reset sequence", function()
    assert.are.equal("\27[r", scroll.scroll_regions())
  end)


  it("should return correct scroll region set sequence", function()
    assert.are.equal("\27[5;10r", scroll.scroll_regions(5, 10))
  end)


  it("should return correct sequence for scrolling up by default 1 line", function()
    assert.are.equal("\27[1S", scroll.scroll_ups())
  end)


  it("should return correct sequence for scrolling up by 5 lines", function()
    assert.are.equal("\27[5S", scroll.scroll_ups(5))
  end)


  it("should return correct sequence for scrolling down by default 1 line", function()
    assert.are.equal("\27[1T", scroll.scroll_downs())
  end)


  it("should return correct sequence for scrolling down by 3 lines", function()
    assert.are.equal("\27[3T", scroll.scroll_downs(3))
  end)


  it("should return empty string for zero vertical scroll", function()
    assert.are.equal("", scroll.scroll_s(0))
  end)


  it("should return correct sequence for positive vertical scroll (down)", function()
    assert.are.equal("\27[3T", scroll.scroll_s(3))
  end)


  it("should return correct sequence for negative vertical scroll (up)", function()
    assert.are.equal("\27[2S", scroll.scroll_s(-2))
  end)


  pending("scroll stack tests", function()
    -- placeholder to do later
  end)

end)
