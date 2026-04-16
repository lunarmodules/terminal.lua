describe("text.color", function()

  local color

  before_each(function()
    color = require("terminal.text.color")
  end)


  after_each(function()
    color = nil
  end)


  describe("fore_seq()", function()

    it("returns a base-color code", function()
      assert.are.equal("\27[30m", color.fore_seq("black"))
    end)


    it("returns an extended-color code", function()
      assert.are.equal("\27[38;5;123m", color.fore_seq(123))
    end)


    it("returns an RGB-color code", function()
      assert.are.equal("\27[38;2;123;123;123m", color.fore_seq(123, 123, 123))
    end)


    it("throws a meaning full error on a bad color-string", function()
      assert.has.error(function()
        color.fore_seq("bad-color")
      end, 'Invalid foreground color string: "bad-color". Expected one of: ' ..
           '"black", "blue", "cyan", "green", "magenta", "red", "white", "yellow"')
    end)


    it("throws a meaning full error on a bad extended color-number", function()
      assert.has.error(function()
        color.fore_seq(256)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.fore_seq(-1)
      end, "expected arg #1 to be a string or an integer 0-255, got -1 (number)")
    end)


    it("throws an error on bad RGB values", function()
      -- nil values
      assert.has.error(function()
        color.fore_seq(nil, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got nil (nil)")
      assert.has.error(function()
        color.fore_seq(123, 123, nil)
      end, "expected arg #3 to be a number 0-255, got nil (nil)")

      -- out of range values
      assert.has.error(function()
        color.fore_seq(256, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.fore_seq(123, 256, 123)
      end, "expected arg #2 to be a number 0-255, got 256 (number)")
      assert.has.error(function()
        color.fore_seq(123, 123, 256)
      end, "expected arg #3 to be a number 0-255, got 256 (number)")

      -- non-numeric values
      assert.has.error(function()
        color.fore_seq(123, true, 123)
      end, "expected arg #2 to be a number 0-255, got true (boolean)")
      assert.has.error(function()
        color.fore_seq(123, 123, true)
      end, "expected arg #3 to be a number 0-255, got true (boolean)")
    end)

  end)



  describe("back_seq()", function()

    it("returns a base-color code", function()
      assert.are.equal("\27[40m", color.back_seq("black"))
    end)


    it("returns an extended-color code", function()
      assert.are.equal("\27[48;5;123m", color.back_seq(123))
    end)


    it("returns an RGB-color code", function()
      assert.are.equal("\27[48;2;123;123;123m", color.back_seq(123, 123, 123))
    end)


    it("throws a meaning full error on a bad color-string", function()
      assert.has.error(function()
        color.back_seq("bad-color")
      end, 'Invalid background color string: "bad-color". Expected one of: ' ..
           '"black", "blue", "cyan", "green", "magenta", "red", "white", "yellow"')
    end)


    it("throws a meaning full error on a bad extended color-number", function()
      assert.has.error(function()
        color.back_seq(256)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.back_seq(-1)
      end, "expected arg #1 to be a string or an integer 0-255, got -1 (number)")
    end)


    it("throws an error on bad RGB values", function()
      -- nil values
      assert.has.error(function()
        color.back_seq(nil, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got nil (nil)")
      assert.has.error(function()
        color.back_seq(123, 123, nil)
      end, "expected arg #3 to be a number 0-255, got nil (nil)")

      -- out of range values
      assert.has.error(function()
        color.back_seq(256, 123, 123)
      end, "expected arg #1 to be a string or an integer 0-255, got 256 (number)")
      assert.has.error(function()
        color.back_seq(123, 256, 123)
      end, "expected arg #2 to be a number 0-255, got 256 (number)")
      assert.has.error(function()
        color.back_seq(123, 123, 256)
      end, "expected arg #3 to be a number 0-255, got 256 (number)")

      -- non-numeric values
      assert.has.error(function()
        color.back_seq(123, true, 123)
      end, "expected arg #2 to be a number 0-255, got true (boolean)")
      assert.has.error(function()
        color.back_seq(123, 123, true)
      end, "expected arg #3 to be a number 0-255, got true (boolean)")
    end)

  end)

end)
