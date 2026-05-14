local helpers = require "spec.helpers"
local tw = require("terminal.text.width")
local text = require("terminal.text")


describe("progress.Bar", function()

  local Bar

  setup(function()
    helpers.load()
    Bar = require("terminal.progress.bar")
  end)


  teardown(function()
    helpers.unload()
  end)


  describe("init()", function()

    it("creates a Bar with default options", function()
      local b = Bar({})
      assert.is_not_nil(b)
    end)


    it("accepts all options and stores them", function()
      local opts = {
        filled_char = "=",
        empty_char = "-",
        tip_chars = {"."},
        left_cap = "[",
        right_cap = "]",
        min = 10,
        max = 200,
        value = 50,
        reverse = true,
        label = "test",
        format = "%d",
        status = "running",
        attr = { fg = "red" },
        cap_attr = { fg = "blue" },
        filled_attr = { fg = "green" },
        empty_attr = { fg = "white" },
        label_attr = { fg = "yellow" },
        status_attr = { fg = "cyan" },
      }
      local b = Bar(opts)
      assert.is_not_nil(b)
    end)


    it("rejects tip_chars if it's an empty array", function()
      assert.has_error(
        function()
          Bar({ tip_chars = {} })
        end,
        "tip_chars must be a non-empty array if provided"
      )
    end)


    it("rejects tip_chars if it's not a table", function()
      assert.has_error(
        function()
          Bar({ tip_chars = "notatable" })
        end,
        "tip_chars must be a non-empty array if provided"
      )
    end)


    it("accepts tip_chars as nil (optional)", function()
      local b = Bar({ tip_chars = nil })
      assert.is_not_nil(b)
    end)


    it("validates that min must be a number if provided", function()
      assert.has_error(
        function()
          Bar({ min = "notanumber" })
        end,
        "min must be a number if provided"
      )
    end)


    it("validates that max must be a number if provided", function()
      assert.has_error(
        function()
          Bar({ max = "notanumber" })
        end,
        "max must be a number if provided"
      )
    end)


    it("rejects when min >= max", function()
      assert.has_error(
        function()
          Bar({ min = 100, max = 100 })
        end,
        "min (100) must be less than max (100)"
      )
      assert.has_error(
        function()
          Bar({ min = 200, max = 100 })
        end,
        "min (200) must be less than max (100)"
      )
    end)


    it("validates that value must be a number if provided", function()
      assert.has_error(
        function()
          Bar({ value = "notanumber" })
        end,
        "value must be a number if provided"
      )
    end)

  end)



  describe("render_bar()", function()

    it("returns a Sequence", function()
      local b = Bar({ value = 50 })
      local seq = b:render_bar(20)
      assert.is_table(seq)
    end)


    it("renders empty when value=min", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 0,
        empty_char = "-",
      })
      assert.are.equal("----------", tostring(b:render_bar(10)))
    end)


    it("renders full when value=max", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 100,
        filled_char = "=",
      })
      assert.are.equal("==========", tostring(b:render_bar(10)))
    end)


    it("renders approximately 50% fill at midpoint", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 50,
        filled_char = "=",
        empty_char = "-",
      })
      assert.are.equal("=====-----", tostring(b:render_bar(10)))
    end)


    it("uses filled_char for filled portion", function()
      local b = Bar({
        value = 75,
        filled_char = "#",
      })
      assert.are.equal("###############     ", tostring(b:render_bar(20)))
    end)


    it("uses empty_char for unfilled portion", function()
      local b = Bar({
        value = 25,
        empty_char = ".",
      })
      assert.are.equal("█████...............", tostring(b:render_bar(20)))
    end)


    it("includes tip_chars when provided and partial fill", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 52,
        filled_char = "=",
        empty_char = "-",
        tip_chars = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" },
      })
      assert.match("[▏▎▍▌▋▊▉]", tostring(b:render_bar(10)))
    end)


    it("omits tip when tip_chars is nil", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 40,
        filled_char = "=",
        empty_char = "-",
        tip_chars = nil,
      })
      assert.are.equal("====------", tostring(b:render_bar(10)))
    end)


    do
      local cases = {
        {
          name = "all single-width",
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "-",
            tip_chars = nil,
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "=====-----",
        },
        {
          name = "filled double-width, others single",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "-",
            tip_chars = nil,
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀------",
        },
        {
          name = "empty double-width, others single",
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "🌍",
            tip_chars = nil,
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "====🌍🌍🌍",  -- extra = extends the filled section; no space padding (case b)
        },
        {
          name = "tip double-width, others single",
          opts = {
            value = 55,
            filled_char = "=",
            empty_char = "-",
            tip_chars = { "⭐" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "====⭐----",  -- 55% → fractional fill triggers the 2-wide tip char
        },
        {
          name = "filled and empty double-width, tip single",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "🌍",
            tip_chars = { "=" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀=🌍🌍 ",  -- both filled+empty are 2w: unavoidable space pad
        },
        {
          name = "filled and tip double-width, empty single",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "-",
            tip_chars = { "⭐" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀⭐----",
        },
        {
          name = "empty and tip double-width, filled single",
          opts = {
            value = 55,
            filled_char = "=",
            empty_char = "🌍",
            tip_chars = { "⭐" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "====⭐🌍🌍",  -- extra = extends filled section between tip and empty (case b)
        },
        {
          name = "all double-width",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "🌍",
            tip_chars = { "⭐" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀⭐🌍🌍",
        },
      }

      for _, case in ipairs(cases) do
        it("character width: " .. case.name, function()
          local b = Bar(case.opts)
          local str = tostring(b:render_bar(case.render_width))
          assert.are.equal(case.expected_output, str)
          assert.are.equal(case.expected_display_width, tw.utf8swidth(str))
        end)
      end
    end


    it("applies filled_attr to filled portion when provided", function()
      local b = Bar({
        value = 50,
        filled_attr = { fg = "red" },
      })
      local str = tostring(b:render_bar(10))
      local expected_seq = text.push_seq({ fg = "red" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("applies empty_attr to empty portion when provided", function()
      local b = Bar({
        value = 50,
        empty_attr = { fg = "blue" },
      })
      local str = tostring(b:render_bar(10))
      local expected_seq = text.push_seq({ fg = "blue" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("handles zero width gracefully", function()
      local b = Bar({ value = 50 })
      local seq = b:render_bar(0)
      assert.is_not_nil(seq)
    end)

  end)



  pending("set()", function()

    it("sets value within range", function()
      local b = Bar({ min = 0, max = 100 })
      b:set(50)
      assert.are.equal(50, b.value)
    end)


    it("clamps value above max", function()
      local b = Bar({ min = 0, max = 100 })
      b:set(150)
      assert.are.equal(100, b.value)
    end)


    it("clamps value below min", function()
      local b = Bar({ min = 0, max = 100 })
      b:set(-10)
      assert.are.equal(0, b.value)
    end)

  end)



  pending("set_status()", function()

    it("sets status text", function()
      local b = Bar()
      b:set_status("downloading")
      assert.are.equal("downloading", b.status)
    end)


    it("replaces previous status", function()
      local b = Bar({ status = "waiting" })
      b:set_status("complete")
      assert.are.equal("complete", b.status)
    end)


    it("handles nil status", function()
      local b = Bar({ status = "downloading" })
      b:set_status(nil)
      assert.are.equal("", b.status)
    end)

  end)



  pending("render()", function()

    it("returns a Sequence and dimensions", function()
      local b = Bar({ value = 50 })
      local seq, w, h = b:render(20)
      assert.is_table(seq)
      assert.are.equal(20, w)
      assert.are.equal(1, h)
    end)


    it("echoes back the requested width", function()
      local b = Bar()
      local _, w = b:render(80)
      assert.are.equal(80, w)
    end)


    it("always returns height of 1", function()
      local b = Bar()
      local _, _, h = b:render(10)
      assert.are.equal(1, h)
    end)


    it("includes label in output", function()
      local b = Bar({
        label = "Progress",
        value = 50,
      })
      local seq = b:render(20)
      local str = tostring(seq)
      assert.is_not_nil(string.find(str, "Progress", 1, true))
    end)


    it("includes left and right caps in output", function()
      local b = Bar({
        left_cap = "[",
        right_cap = "]",
        value = 50,
      })
      local seq = b:render(20)
      local str = tostring(seq)
      assert.is_not_nil(string.find(str, "[", 1, true))
      assert.is_not_nil(string.find(str, "]", 1, true))
    end)


    it("formats progress value with format string", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 50,
        format = "%d%%",
      })
      local seq = b:render(20)
      local str = tostring(seq)
      assert.is_not_nil(string.find(str, "50%", 1, true))
    end)


    it("includes status text in output", function()
      local b = Bar({
        status = "downloading",
        value = 50,
      })
      local seq = b:render(20)
      local str = tostring(seq)
      assert.is_not_nil(string.find(str, "downloading", 1, true))
    end)


    it("measures fixed elements and allocates remainder to bar", function()
      local b = Bar({
        label = "X",
        left_cap = "[",
        right_cap = "]",
        format = "%d",
        status = "S",
        value = 50,
      })
      local seq = b:render(10)
      assert.is_not_nil(seq)
    end)


    it("applies overall attr when provided", function()
      local b = Bar({
        attr = { fg = "red" },
        value = 50,
      })
      local seq = b:render(10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "red" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("applies cap_attr when provided", function()
      local b = Bar({
        left_cap = "[",
        cap_attr = { fg = "blue" },
        value = 50,
      })
      local seq = b:render(10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "blue" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("applies label_attr when provided", function()
      local b = Bar({
        label = "L",
        label_attr = { fg = "green" },
        value = 50,
      })
      local seq = b:render(10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "green" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("applies status_attr when provided", function()
      local b = Bar({
        status = "S",
        status_attr = { fg = "cyan" },
        value = 50,
      })
      local seq = b:render(10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "cyan" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
    end)


    it("handles reverse mode", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 90,
        reverse = true,
        filled_char = "█",
        empty_char = " ",
      })
      local seq = b:render(10)
      assert.is_not_nil(seq)
    end)


    it("handles format as function", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 50,
        format = function(v, mn, mx)
          return string.format("%d/%d", v, mx)
        end,
      })
      local seq = b:render(20)
      local str = tostring(seq)
      assert.is_not_nil(string.find(str, "50/100", 1, true))
    end)

  end)

end)
