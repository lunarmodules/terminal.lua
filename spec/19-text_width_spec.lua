local helpers = require "spec.helpers"
local utf8 = require("utf8")

describe("terminal.text.width", function()

  local text

  before_each(function()
    helpers.load()
    text = require("terminal.text")
  end)


  after_each(function()
    helpers.unload()
  end)



  it("ASCII width test", function()
    assert.are.equal(1, text.width.utf8cwidth("a"))
    assert.are.equal(3, text.width.utf8swidth("abc"))
  end)


  it("ambiguous-width defaults to 1", function()
    local circle = utf8.char(0x25CB)
    assert.are.equal(1, text.width.utf8cwidth(circle))
  end)



  describe("set_ambiguous_width()", function()

    it("configures forwarded width", function()
      text.width.set_ambiguous_width(2)
      assert.are.equal(2, text.width.utf8cwidth(utf8.char(0x00A1)))
      assert.are.equal(4, text.width.utf8swidth(utf8.char(0x00A1) .. utf8.char(0x00A1)))

      text.width.set_ambiguous_width(1)
      assert.are.equal(1, text.width.utf8cwidth(utf8.char(0x00A1)))
      assert.are.equal(2, text.width.utf8swidth(utf8.char(0x00A1) .. utf8.char(0x00A1)))
    end)

  end)

end)
