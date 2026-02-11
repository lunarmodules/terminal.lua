describe("text", function()

  local text

  before_each(function()
    text = require("terminal.text")
  end)

  after_each(function()
    text = nil
  end)



  describe("underline_seq()", function()

    it("returns 'on' sequence", function()
      assert.are.equal("\27[4m", text.underline_seq())
    end)


    it("returns 'off' sequence", function()
      assert.are.equal("\27[24m", text.underline_seq(false))
    end)


    it("defaults to 'on'", function()
      assert.are.equal("\27[4m", text.underline_seq(true))
    end)

  end)



  describe("blink_seq()", function()

    it("returns 'on' sequence", function()
      assert.are.equal("\27[5m", text.blink_seq())
    end)


    it("returns 'off' sequence", function()
      assert.are.equal("\27[25m", text.blink_seq(false))
    end)


    it("defaults to 'on'", function()
      assert.are.equal("\27[5m", text.blink_seq(true))
    end)

  end)



  describe("reverse_seq()", function()

    it("returns 'on' sequence", function()
      assert.are.equal("\27[7m", text.reverse_seq())
    end)


    it("returns 'off' sequence", function()
      assert.are.equal("\27[27m", text.reverse_seq(false))
    end)


    it("defaults to 'on'", function()
      assert.are.equal("\27[7m", text.reverse_seq(true))
    end)

  end)



  describe("brightness_seq()", function()

    it("0 sets 'invisible'", function()
      assert.are.equal("\027[22m\027[8m", text.brightness_seq(0))
    end)


    it("1 sets 'dim'", function()
      assert.are.equal("\027[22m\027[28m\027[2m", text.brightness_seq(1))
    end)


    it("2 sets 'normal'", function()
      assert.are.equal("\027[22m\027[28m", text.brightness_seq(2))
    end)


    it("3 sets 'bright'", function()
      assert.are.equal("\027[22m\027[28m\027[1m", text.brightness_seq(3))
    end)


    for key, val in pairs{
                      off = 0,
                      invisible = 0,
                      low = 1,
                      dim = 1,
                      normal = 2,
                      high = 3,
                      bright = 3,
                      bold = 3,
                    } do

      it("sets '"..key.."' to "..val, function()
        assert.are.equal(text.brightness_seq(val), text.brightness_seq(key))
      end)

    end


    it("returns a meaningfull error on bad input", function()
      assert.has_error(function() text.brightness_seq("bad") end,
            'Invalid brightness setting: "bad". Expected one of: 0, 1, 2, 3, '..
            '"bold", "bright", "dim", "high", "invisible", "low", "normal", "off"')
    end)

  end)

end)
