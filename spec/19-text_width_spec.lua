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


  it("set_ambiguous_width configures forwarded width", function()
    local system = require("system")
    local real_utf8cwidth = system.utf8cwidth

    -- Mock system.utf8cwidth to return the ambiguous-width parameter directly,
    -- so we can verify that set_ambiguous_width propagates the value correctly.
    system.utf8cwidth = function(_, aw)
      return aw
    end

    package.loaded["terminal.text.width"] = nil
    local width = require("terminal.text.width")
    local utf8 = require("utf8")

    local ok, err = pcall(function()
      width.set_ambiguous_width(2)
      -- single-character width should forward ambiguous_width = 2
      assert.are.equal(2, width.utf8cwidth(utf8.char(0x00A1)))
      -- string width should also respect the configured ambiguous width
      assert.are.equal(4, width.utf8swidth(utf8.char(0x00A1) .. utf8.char(0x00A1)))
    end)

    width.set_ambiguous_width(1)
    system.utf8cwidth = real_utf8cwidth
    package.loaded["terminal.text.width"] = nil

    assert.is_true(ok, err)
  end)

end)