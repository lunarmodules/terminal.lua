describe("Clear Module Tests", function()

  local clear

  setup(function()
    clear = require "terminal.clear"
  end)



  it("should return correct ANSI sequence for clearing entire screen", function()
    assert.are.equal("\27[2J", clear.screen_seq())
  end)


  it("should return correct ANSI sequence for clearing line", function()
    assert.are.equal("\27[2K", clear.line_seq())
  end)


  it("should return correct ANSI sequence for clearing line begin (bol)", function()
    assert.are.equal("\27[1K", clear.bol_seq())
  end)


  it("should return correct ANSI sequence for clearing line end (eol)", function()
    assert.are.equal("\27[0K", clear.eol_seq())
  end)


  it("should return correct ANSI sequence for clearing top of screen", function()
    assert.are.equal("\27[1J", clear.top_seq())
  end)


  it("should return correct ANSI sequence for clearing bottom of screen", function()
    assert.are.equal("\27[0J", clear.bottom_seq())
  end)


  it("should return correct ANSI sequence for clearing a box", function()
    local res = clear.box_seq(2, 2)
    assert.are.equal("  \27[2D\27[1B  \27[2D\27[1A", res)

    local res = clear.box_seq(1, 1)
    assert.are.equal(" \27[1D", res)

    local res = clear.box_seq(2, 0)
    assert.are.equal("", res)

    local res = clear.box_seq(0, 2)
    assert.are.equal("", res)
  end)

end)
