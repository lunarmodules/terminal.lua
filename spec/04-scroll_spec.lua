describe("Scroll Module Tests", function()

  local scroll, old_sys_termsize

  setup(function()
    local sys = require "system"
    old_sys_termsize = sys.termsize
    if os.getenv("GITHUB_ACTIONS") then
      sys.termsize = function()
        return 25, 80
      end
    end

    scroll = require "terminal.scroll"
  end)


  teardown(function()
    require("system").termsize = old_sys_termsize
  end)



  it("should return default scroll region reset sequence", function()
    assert.are.equal("\27[r", scroll.reset_seq())
  end)


  it("should return correct scroll region set sequence", function()
    assert.are.equal("\27[5;10r", scroll.set_seq(5, 10))
  end)


  it("should return correct sequence for scrolling up by default 1 line", function()
    assert.are.equal("\27[1S", scroll.up_seq())
  end)


  it("should return correct sequence for scrolling up by 5 lines", function()
    assert.are.equal("\27[5S", scroll.up_seq(5))
  end)


  it("should return correct sequence for scrolling down by default 1 line", function()
    assert.are.equal("\27[1T", scroll.down_seq())
  end)


  it("should return correct sequence for scrolling down by 3 lines", function()
    assert.are.equal("\27[3T", scroll.down_seq(3))
  end)


  it("should return empty string for zero vertical scroll", function()
    assert.are.equal("", scroll.vertical_seq(0))
  end)


  it("should return correct sequence for positive vertical scroll (down)", function()
    assert.are.equal("\27[3T", scroll.vertical_seq(3))
  end)


  it("should return correct sequence for negative vertical scroll (up)", function()
    assert.are.equal("\27[2S", scroll.vertical_seq(-2))
  end)

end)
