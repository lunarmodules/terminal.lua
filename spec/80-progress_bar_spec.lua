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


    pending("accounts for character width in render_bar", function()
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
          expected_output = "🚀🚀---",
        },
        {
          name = "empty double-width, others single",
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "🚀",
            tip_chars = nil,
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "=====🚀🚀",
        },
        {
          name = "tip double-width, others single",
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "-",
            tip_chars = { "🚀" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "====🚀----",
        },
        {
          name = "filled and empty double-width, tip single",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "🚀",
            tip_chars = nil,
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀🚀",
        },
        {
          name = "filled and tip double-width, empty single",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "-",
            tip_chars = { "🚀" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀--",
        },
        {
          name = "empty and tip double-width, filled single",
          opts = {
            value = 50,
            filled_char = "=",
            empty_char = "🚀",
            tip_chars = { "🚀" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "====🚀🚀",
        },
        {
          name = "all double-width",
          opts = {
            value = 50,
            filled_char = "🚀",
            empty_char = "🚀",
            tip_chars = { "🚀" },
          },
          render_width = 10,
          expected_display_width = 10,
          expected_output = "🚀🚀",
        },
      }

      for _, case in ipairs(cases) do
        local b = Bar(case.opts)
        local str = tostring(b:render_bar(case.render_width))
        assert.are.equal(case.expected_output, str, case.name)
        assert.are.equal(case.expected_display_width, tw.utf8swidth(str), case.name)
      end
    end)


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

end)
