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

    pending("creates a Bar with default options", function()
    end)


    pending("accepts all options and stores them", function()
    end)


    pending("rejects tip_chars if it's an empty array", function()
    end)


    pending("accepts tip_chars as nil (optional)", function()
    end)


    pending("validates that min must be a number if provided", function()
    end)


    pending("validates that max must be a number if provided", function()
    end)


    pending("rejects when min >= max", function()
    end)


    pending("validates that value must be a number if provided", function()
    end)

  end)

end)
