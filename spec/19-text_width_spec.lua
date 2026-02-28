describe("terminal.text.width (LuaSystem delegation)", function()

  local text

  setup(function()
    text = require("terminal.text")
  end)



  it("ASCII width test", function()
    assert.are.equal(1, text.width.utf8cwidth("a"))
    assert.are.equal(3, text.width.utf8swidth("abc"))
  end)


  it("Ambiguous character test", function()
    local utf8 = require("utf8")
    local circle = utf8.char(0x25CB)
    assert.are.equal(1, text.width.utf8cwidth(circle))
  end)

end)
