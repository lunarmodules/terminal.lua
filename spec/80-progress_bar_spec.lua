local helpers = require "spec.helpers"


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

    pending("returns a Sequence", function()
    end)


    pending("renders empty when value=min", function()
    end)


    pending("renders full when value=max", function()
    end)


    pending("renders approximately 50% fill at midpoint", function()
    end)


    pending("uses filled_char for filled portion", function()
    end)


    pending("uses empty_char for unfilled portion", function()
    end)


    pending("includes tip_chars when provided and partial fill", function()
    end)


    pending("omits tip when tip_chars is nil", function()
    end)


    pending("handles double-width filled_char correctly", function()
    end)


    pending("handles double-width empty_char correctly", function()
    end)


    pending("handles double-width tip_chars correctly", function()
    end)


    pending("applies filled_attr to filled portion when provided", function()
    end)


    pending("applies empty_attr to empty portion when provided", function()
    end)


    pending("omits attrs when not provided", function()
    end)


    pending("handles zero width gracefully", function()
    end)

  end)

end)
