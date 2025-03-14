describe("Color Module Tests", function()
  local color

  setup(function()
    color = require "terminal.color".fg_base_colors
  end)

  it("should return correct ANSI code for valid colors", function()
    assert.are.equal("\27[30m", color.black)
    assert.are.equal("\27[31m", color.red)
    assert.are.equal("\27[32m", color.green)
    assert.are.equal("\27[33m", color.yellow)
    assert.are.equal("\27[34m", color.blue)
    assert.are.equal("\27[35m", color.magenta)
    assert.are.equal("\27[36m", color.cyan)
    assert.are.equal("\27[37m", color.white)
  end)

  it("should throw an error for invalid colors", function()
    assert.has_error(function() return color.invalid end, "invalid string-based color: invalid")
  end)
end)