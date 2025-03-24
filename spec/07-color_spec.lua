describe("text.color", function()

  local color

  before_each(function()
    color = require("terminal.text.color")
  end)

  after_each(function()
    color = nil
  end)


  describe("fores()", function()

    it("returns a base-color code", function()
      assert.are.equal("\27[30m", color.fores("black"))
    end)


    it("returns an extended-color code", function()
      assert.are.equal("\27[38;5;123m", color.fores(123))
    end)


    it("returns an RGB-color code", function()
      assert.are.equal("\27[38;2;123;123;123m", color.fores(123, 123, 123))
    end)


    it("throws a meaning full error on a bad color-string", function()
      assert.has.error(function()
        color.fores("bad-color")
      end, 'Invalid foreground color string: "bad-color". Expected one of: ' ..
           '"black", "blue", "cyan", "green", "magenta", "red", "white", "yellow"')
    end)


    it("throws a meaning full error on a bad extended color-number", function()
      assert.has.error(function()
        color.fores(256)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.fores(-1)
      end, "expected arg #1 to be a string or an integer 0-255, got -1 (number)")
    end)


    it("throws an error on bad RGB values", function()
      -- nil values
      assert.has.error(function()
        color.fores(nil, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got nil (nil)")
      assert.has.error(function()
        color.fores(123, 123, nil)
      end, "expected arg #3 to be a number 0-255, got nil (nil)")

      -- out of range values
      assert.has.error(function()
        color.fores(256, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.fores(123, 256, 123)
      end, "expected arg #2 to be a number 0-255, got 256 (number)")
      assert.has.error(function()
        color.fores(123, 123, 256)
      end, "expected arg #3 to be a number 0-255, got 256 (number)")

      -- non-numeric values
      assert.has.error(function()
        color.fores(123, true, 123)
      end, "expected arg #2 to be a number 0-255, got true (boolean)")
      assert.has.error(function()
        color.fores(123, 123, true)
      end, "expected arg #3 to be a number 0-255, got true (boolean)")
    end)

  end)



  describe("backs()", function()

    it("returns a base-color code", function()
      assert.are.equal("\27[40m", color.backs("black"))
    end)


    it("returns an extended-color code", function()
      assert.are.equal("\27[48;5;123m", color.backs(123))
    end)


    it("returns an RGB-color code", function()
      assert.are.equal("\27[48;2;123;123;123m", color.backs(123, 123, 123))
    end)


    it("throws a meaning full error on a bad color-string", function()
      assert.has.error(function()
        color.backs("bad-color")
      end, 'Invalid background color string: "bad-color". Expected one of: ' ..
           '"black", "blue", "cyan", "green", "magenta", "red", "white", "yellow"')
    end)


    it("throws a meaning full error on a bad extended color-number", function()
      assert.has.error(function()
        color.backs(256)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.backs(-1)
      end, "expected arg #1 to be a string or an integer 0-255, got -1 (number)")
    end)


    it("throws an error on bad RGB values", function()
      -- nil values
      assert.has.error(function()
        color.backs(nil, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got nil (nil)")
      assert.has.error(function()
        color.backs(123, 123, nil)
      end, "expected arg #3 to be a number 0-255, got nil (nil)")

      -- out of range values
      assert.has.error(function()
        color.backs(256, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.backs(123, 256, 123)
      end, "expected arg #2 to be a number 0-255, got 256 (number)")
      assert.has.error(function()
        color.backs(123, 123, 256)
      end, "expected arg #3 to be a number 0-255, got 256 (number)")

      -- non-numeric values
      assert.has.error(function()
        color.backs(123, true, 123)
      end, "expected arg #2 to be a number 0-255, got true (boolean)")
      assert.has.error(function()
        color.backs(123, 123, true)
      end, "expected arg #3 to be a number 0-255, got true (boolean)")
    end)

  end)

end)
