describe("Color Module Tests", function()
  
  local fg_color
  local bg_color

  setup(function()
    fg_color = require "terminal.color".fg_base_colors
    bg_color = require "terminal.color".bg_base_colors
  end)

  it("should return correct ANSI code for valid colors", function()
    assert.are.equal("\27[30m", fg_color.black)
    assert.are.equal("\27[31m", fg_color.red)
    assert.are.equal("\27[32m", fg_color.green)
    assert.are.equal("\27[33m", fg_color.yellow)
    assert.are.equal("\27[34m", fg_color.blue)
    assert.are.equal("\27[35m", fg_color.magenta)
    assert.are.equal("\27[36m", fg_color.cyan)
    assert.are.equal("\27[37m", fg_color.white)
  end)
  it("should return correct ANSI code for valid colors", function()
    assert.are.equal("\27[40m", bg_color.black)
    assert.are.equal("\27[41m", bg_color.red)
    assert.are.equal("\27[42m", bg_color.green)
    assert.are.equal("\27[43m", bg_color.yellow)
    assert.are.equal("\27[44m", bg_color.blue)
    assert.are.equal("\27[45m",bg_color.magenta)
    assert.are.equal("\27[46m", bg_color.cyan)
    assert.are.equal("\27[47m", bg_color.white)
  end)

  it("should throw an error for invalid colors", function()
    assert.has_error(function() return fg_color.invalid end, "invalid string-based color: invalid")
    assert.has_error(function() return bg_color.invalid end, "invalid string-based color: invalid")
  end)
end)