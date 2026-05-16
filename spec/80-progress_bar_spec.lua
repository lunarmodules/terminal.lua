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
        pad_char = ".",
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


    it("rejects pad_char if it's not a string", function()
      assert.has_error(
        function()
          Bar({ pad_char = 42 })
        end,
        "pad_char must be a single-width character or an empty string if provided"
      )
    end)


    it("rejects pad_char if it's a double-width character", function()
      assert.has_error(
        function()
          Bar({ pad_char = "🚀" })
        end,
        "pad_char must be a single-width character or an empty string if provided"
      )
    end)


    it("accepts pad_char as an empty string", function()
      local b = Bar({ pad_char = "" })
      assert.is_not_nil(b)
    end)


    it("accepts pad_char as a single-width character", function()
      local b = Bar({ pad_char = "." })
      assert.is_not_nil(b)
    end)


    it("defaults mode to clamp", function()
      local b = Bar({})
      assert.are.equal(Bar.modes.clamp, b.mode)
    end)


    it("accepts all valid mode constants", function()
      for _, mode in pairs({ Bar.modes.clamp, Bar.modes.loop, Bar.modes.bounce }) do
        local b = Bar({ mode = mode })
        assert.are.equal(mode, b.mode)
      end
    end)


    it("rejects mode if it is not a string", function()
      assert.has_error(
        function()
          Bar({ mode = 42 })
        end,
        'Invalid bar mode: 42. Expected one of: "bounce", "clamp", "loop"'
      )
    end)


    it("rejects an unknown mode string", function()
      assert.has_error(
        function()
          Bar({ mode = "zigzag" })
        end,
        'Invalid bar mode: "zigzag". Expected one of: "bounce", "clamp", "loop"'
      )
    end)

  end)



  describe("render_bar()", function()

    it("returns a Sequence and actual width", function()
      local b = Bar({ value = 50 })
      local seq, actual_width = b:render_bar(0.5, 20)
      assert.is_table(seq)
      assert.are.equal(20, actual_width)
    end)


    it("renders empty when value=min", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 0,
        empty_char = "-",
      })
      local seq, actual_width = b:render_bar(0, 10)
      assert.are.equal("----------", tostring(seq))
      assert.are.equal(10, actual_width)
    end)


    it("renders full when value=max", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 100,
        filled_char = "=",
      })
      local seq, actual_width = b:render_bar(1, 10)
      assert.are.equal("==========", tostring(seq))
      assert.are.equal(10, actual_width)
    end)


    it("renders approximately 50% fill at midpoint", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 50,
        filled_char = "=",
        empty_char = "-",
      })
      local seq, actual_width = b:render_bar(0.5, 10)
      assert.are.equal("=====-----", tostring(seq))
      assert.are.equal(10, actual_width)
    end)


    it("uses filled_char for filled portion", function()
      local b = Bar({
        value = 75,
        filled_char = "#",
      })
      local seq, actual_width = b:render_bar(0.75, 20)
      assert.are.equal("###############     ", tostring(seq))
      assert.are.equal(20, actual_width)
    end)


    it("uses empty_char for unfilled portion", function()
      local b = Bar({
        value = 25,
        empty_char = ".",
      })
      local seq, actual_width = b:render_bar(0.25, 20)
      assert.are.equal("█████...............", tostring(seq))
      assert.are.equal(20, actual_width)
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
      assert.match("[▏▎▍▌▋▊▉]", tostring(b:render_bar(0.52, 10)))
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
      local seq, actual_width = b:render_bar(0.4, 10)
      assert.are.equal("====------", tostring(seq))
      assert.are.equal(10, actual_width)
    end)


    do
      local cases = {
        {
          name = "all single-width",
          fraction = 0.5,
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
          fraction = 0.5,
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
          fraction = 0.5,
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
          fraction = 0.55,
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
          fraction = 0.5,
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
          fraction = 0.5,
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
          fraction = 0.55,
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
          fraction = 0.5,
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
          local seq, actual_width = b:render_bar(case.fraction, case.render_width)
          local str = tostring(seq)
          assert.are.equal(case.expected_output, str)
          assert.are.equal(case.expected_display_width, tw.utf8swidth(str))
          assert.are.equal(case.render_width, actual_width)
        end)
      end
    end


    it("applies filled_attr to filled portion when provided", function()
      local b = Bar({
        value = 50,
        filled_attr = { fg = "red" },
      })
      local seq, actual_width = b:render_bar(0.5, 10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "red" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
      assert.are.equal(10, actual_width)
    end)


    it("applies empty_attr to empty portion when provided", function()
      local b = Bar({
        value = 50,
        empty_attr = { fg = "blue" },
      })
      local seq, actual_width = b:render_bar(0.5, 10)
      local str = tostring(seq)
      local expected_seq = text.push_seq({ fg = "blue" })
      assert.is_not_nil(string.find(str, expected_seq, 1, true))
      assert.are.equal(10, actual_width)
    end)


    it("handles zero width gracefully", function()
      local b = Bar({ value = 50 })
      local seq, actual_width = b:render_bar(0.5, 0)
      assert.is_not_nil(seq)
      assert.are.equal(0, actual_width)
    end)


    it("uses custom pad_char when fill does not cover full width", function()
      local b = Bar({
        value = 0,
        filled_char = "=",
        empty_char = "🌍",
        pad_char = ".",
      })
      local seq, actual_width = b:render_bar(0, 3)
      assert.are.equal("🌍.", tostring(seq))
      assert.are.equal(3, actual_width)
    end)


    it("omits padding when pad_char is empty string, actual_width is shorter", function()
      local b = Bar({
        value = 0,
        filled_char = "=",
        empty_char = "🌍",
        pad_char = "",
      })
      local seq, actual_width = b:render_bar(0, 3)
      assert.are.equal("🌍", tostring(seq))
      assert.are.equal(2, actual_width)
    end)


    do
      -- expected[w] is the exact string render_bar should produce at render-width w (0-7).
      -- display width of each expected string must equal w.
      local narrow_cases = {
        {
          name = "single-width chars, value=50",
          fraction = 0.5,
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "-",
            tip_chars = { "*" },
          },
          expected = {
            [0] = "",
            [1] = "*",
            [2] = "*-",
            [3] = "=*-",
            [4] = "=*--",
            [5] = "==*--",
            [6] = "==*---",
            [7] = "===*---",
          },
        },
        {
          name = "2w filled char, value=100",
          fraction = 1,
          opts = {
            value = 100,
            filled_char = "🚀",
            empty_char = "-",
            tip_chars = { "*" },
          },
          expected = {
            [0] = "",
            [1] = "*",
            [2] = "*-",
            [3] = "🚀*",
            [4] = "🚀*-",
            [5] = "🚀🚀*",
            [6] = "🚀🚀*-",
            [7] = "🚀🚀🚀*",
          },
        },
        {
          name = "2w empty char, value=0",
          fraction = 0,
          opts = {
            value = 0,
            filled_char = "=",
            empty_char = "🌍",
            tip_chars = { "*" },
          },
          expected = {
            [0] = "",
            [1] = "*",
            [2] = "* ",
            [3] = "*🌍",
            [4] = "*🌍 ",
            [5] = "*🌍🌍",
            [6] = "*🌍🌍 ",
            [7] = "*🌍🌍🌍",
          },
        },
        {
          name = "2w tip char, value=55",
          fraction = 0.55,
          opts = {
            value = 55,
            filled_char = "=",
            empty_char = "-",
            tip_chars = { "⭐" },
          },
          expected = {
            [0] = "",
            [1] = " ",       -- tip (2w) does not fit; fallback: no-tip behaviour
            [2] = "⭐",
            [3] = "⭐-",
            [4] = "=⭐-",
            [5] = "=⭐--",
            [6] = "==⭐--",
            [7] = "==⭐---",
          },
        },
        {
          name = "2w chars, value=0",
          fraction = 0,
          opts = {
            value = 0,
            filled_char = "🚀",
            empty_char = "🌍",
            tip_chars = { "⭐" },
          },
          expected = {
            [0] = "",
            [1] = " ",
            [2] = "⭐",
            [3] = "⭐ ",
            [4] = "⭐🌍",
            [5] = "⭐🌍 ",
            [6] = "⭐🌍🌍",
            [7] = "⭐🌍🌍 ",
          },
        },
        {
          name = "2w chars, value=55",
          fraction = 0.55,
          opts = {
            value = 55,
            filled_char = "🚀",
            empty_char = "🌍",
            tip_chars = { "⭐" },
          },
          expected = {
            [0] = "",
            [1] = " ",
            [2] = "⭐",
            [3] = "⭐ ",
            [4] = "⭐🌍",
            [5] = "⭐🌍 ",
            [6] = "🚀⭐🌍",
            [7] = "🚀⭐🌍 ",
          },
        },
        {
          name = "2w chars, value=100",
          fraction = 1,
          opts = {
            value = 100,
            filled_char = "🚀",
            empty_char = "🌍",
            tip_chars = { "⭐" },
          },
          expected = {
            [0] = "",
            [1] = " ",
            [2] = "⭐",
            [3] = "⭐ ",
            [4] = "🚀⭐",
            [5] = "🚀⭐ ",
            [6] = "🚀🚀⭐",
            [7] = "🚀🚀⭐ ",
          },
        },
      }

      for _, case in ipairs(narrow_cases) do
        it("narrow width: " .. case.name, function()
          local b = Bar(case.opts)
          for render_width = 0, 7 do
            local seq, actual_width = b:render_bar(case.fraction, render_width)
            local str = tostring(seq)
            assert.are.equal(case.expected[render_width], str, "width=" .. render_width)
            assert.are.equal(render_width, actual_width, "width=" .. render_width)
          end
        end)
      end
    end

  end)



  describe("set()", function()

    it("sets value within range", function()
      local b = Bar({ min = 0, max = 100 })
      b:set(50)
      assert.are.equal(50, b:get())
    end)


    it("checks value to be a number", function()
      local b = Bar()
      assert.has_error(
        function()
          b:set("notanumber")
        end)
    end)

  end)



  describe("set_status()", function()

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



  describe("render()", function()

    it("returns a Sequence and dimensions", function()
      local b = Bar({ value = 50 })
      local seq, w, h = b:render(20)
      assert.are.equal(" █████████          ", tostring(seq))
      assert.are.equal(20, w)
      assert.are.equal(1, h)
    end)


    it("echoes back the requested width", function()
      local b = Bar()
      local seq, w = b:render(80)
      assert.are.equal(string.rep(" ", 80), tostring(seq))
      assert.are.equal(80, w)
    end)


    it("returns height of 1", function()
      local b = Bar()
      local seq, _, h = b:render(10)
      assert.are.equal("          ", tostring(seq))
      assert.are.equal(1, h)
    end)


    it("includes label in output", function()
      local b = Bar({
        label = "Progress",
        value = 50,
      })
      local seq = b:render(20)
      assert.are.equal("Progress █████      ", tostring(seq))
    end)


    it("includes left and right caps in output", function()
      local b = Bar({
        left_cap = "[",
        right_cap = "]",
        value = 50,
      })
      local seq = b:render(20)
      assert.are.equal("[█████████         ]", tostring(seq))
    end)


    it("formats progress value with format string", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 50,
        format = "%d%%",
      })
      local seq = b:render(20)
      assert.are.equal(" ███████         50%", tostring(seq))
    end)


    it("includes status text in output", function()
      local b = Bar({
        status = "downloading",
        value = 50,
      })
      local seq = b:render(20)
      assert.are.equal(" ███     downloading", tostring(seq))
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
      assert.are.equal("X[██  ]50S", tostring(seq))
    end)


    it("applies overall attr when provided", function()
      local b = Bar({
        attr = { fg = "red" },
        value = 50,
      })
      local seq = b:render(10)
      local t = require("terminal.text")
      local push = t.push_seq({ fg = "red" })
      local pop = t.pop_seq()
      assert.are.equal(push .. " ████     " .. pop, tostring(seq))
    end)


    it("applies cap_attr when provided", function()
      local b = Bar({
        left_cap = "[",
        cap_attr = { fg = "blue" },
        value = 50,
      })
      local seq = b:render(10)
      local t = require("terminal.text")
      local push = t.push_seq({ fg = "blue" })
      local pop = t.pop_seq()
      assert.are.equal(push .. "[" .. pop .. "████    " .. push .. " " .. pop, tostring(seq))
    end)


    it("applies label_attr when provided", function()
      local b = Bar({
        label = "L",
        label_attr = { fg = "green" },
        value = 50,
      })
      local seq = b:render(10)
      local t = require("terminal.text")
      local push = t.push_seq({ fg = "green" })
      local pop = t.pop_seq()
      assert.are.equal(push .. "L" .. pop .. " ███     ", tostring(seq))
    end)


    it("applies status_attr when provided", function()
      local b = Bar({
        status = "S",
        status_attr = { fg = "cyan" },
        value = 50,
      })
      local seq = b:render(10)
      local t = require("terminal.text")
      local push = t.push_seq({ fg = "cyan" })
      local pop = t.pop_seq()
      assert.are.equal(" ███     " .. push .. "S" .. pop, tostring(seq))
    end)


    it("handles reverse mode", function()
      local b = Bar({
        min = 0,
        max = 100,
        value = 25,
        reverse = true,
        filled_char = "█",
        empty_char = " ",
      })
      local seq = b:render(10)
      assert.are.equal(" ██████   ", tostring(seq))
    end)

  end)

end)
