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


  it("should return correct ANSI sequence for clearing line start", function()
    assert.are.equal("\27[1K", clear.bol_seq())
  end)


  it("should return correct ANSI sequence for clearing line end", function()
    assert.are.equal("\27[0K", clear.eol_seq())
  end)


  it("should return correct ANSI sequence for clearing top of screen", function()
    assert.are.equal("\27[1J", clear.top_seq())
  end)


  it("should return correct ANSI sequence for clearing bottom of screen", function()
    assert.are.equal("\27[0J", clear.bottom_seq())
  end)

end)
