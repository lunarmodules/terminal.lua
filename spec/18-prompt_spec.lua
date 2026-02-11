local helpers = require "spec.helpers"


describe("terminal.cli.prompt", function()

  local Prompt

  before_each(function()
    helpers.load()
    Prompt = require("terminal.cli.prompt")
  end)


  after_each(function()
    helpers.unload()
  end)



  describe("init() with empty value", function()

    it("initializes with empty string value", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "",
      }

      assert.are.equal("", tostring(prompt.value))
      assert.are.equal(1, prompt.value:pos_char())
    end)


    it("initializes with nil value (defaults to empty)", function()
      local prompt = Prompt {
        prompt = "Enter: ",
      }

      assert.are.equal("", tostring(prompt.value))
    end)

  end)



  describe("run() cancelled behavior", function()

    it("returns nil and 'cancelled' when Esc pressed with cancellable=true", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "test",
        cancellable = true,
      }

      -- Queue Esc key (from keymap)
      helpers._push_input(helpers.keys.esc)

      local result, err = prompt:run()

      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)


    it("treats Ctrl+C as cancel when cancellable=true", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "test",
        cancellable = true,
      }

      -- Queue Ctrl+C key (from keymap)
      helpers._push_input(helpers.keys.ctrl_c)

      local result, err = prompt:run()

      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)

  end)



  describe("run() returned behavior", function()

    it("returns value and no error when Enter pressed", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "hello",
      }

      -- Queue Enter key (platform-specific)
      helpers._push_input(helpers.keys.enter)

      local result, err = prompt:run()

      assert.are.equal("hello", result)
      assert.is_nil(err)
    end)


    it("returns empty string when Enter pressed with empty value", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "",
      }

      -- Queue Enter key (platform-specific)
      helpers._push_input(helpers.keys.enter)

      local result, err = prompt:run()

      assert.are.equal("", result)
      assert.is_nil(err)
    end)

  end)

end)
