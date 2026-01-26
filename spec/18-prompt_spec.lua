--- Tests for terminal.cli.prompt edge cases
-- Covers: empty value, cancelled/returned behavior, UTF-8 content

describe("terminal.cli.prompt", function()

  local Prompt
  local t
  local old_size, old_write, old_print, old_readansi

  -- Input queue for mocked readansi
  local input_queue = {}

  before_each(function()
  t = require("terminal")

  -- mock terminal
  old_size = t.size
  t.size = function() return 24, 80 end

  old_write = t.output.write
  t.output.write = function() end

  old_print = t.output.print
  t.output.print = function() end

  old_readansi = t.input.readansi
  t.input.readansi = function()
    if #input_queue > 0 then
      local entry = table.remove(input_queue, 1)
      return entry.key, entry.keytype, entry.modifiers
    end
    return nil, "timeout"
  end

  input_queue = {}
  Prompt = require("terminal.cli.prompt")
  end)

  after_each(function()
    t.size = old_size
    t.output.write = old_write
    t.output.print = old_print
    t.input.readansi = old_readansi

    package.loaded["terminal.cli.prompt"] = nil
    Prompt = nil
  end)


  -- Helper to queue a key press
  local function queue_key(key, keytype, modifiers)
    table.insert(input_queue, { key = key, keytype = keytype, modifiers = modifiers })
  end

  -- Get the correct Enter key for the platform (ctrl_j on macOS, ctrl_m on Windows)
  local sys = require("system")
  local ENTER_KEY = sys.windows and "\r" or "\n"



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

      -- Queue Esc key
      queue_key("\27", "ansi")

      local result, status = prompt:run()

      assert.is_nil(result)
      assert.are.equal("cancelled", status)
    end)

  end)



  describe("run() returned behavior", function()

    it("returns value and 'returned' when Enter pressed", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "hello",
      }

      -- Queue Enter key (platform-specific)
      queue_key(ENTER_KEY, "char")

      local result, status = prompt:run()

      assert.are.equal("hello", result)
      assert.are.equal("returned", status)
    end)


    it("returns empty string when Enter pressed with empty value", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "",
      }

      -- Queue Enter key (platform-specific)
      queue_key(ENTER_KEY, "char")

      local result, status = prompt:run()

      assert.are.equal("", result)
      assert.are.equal("returned", status)
    end)

  end)



  describe("UTF-8 content handling", function()

    it("initializes with UTF-8 value correctly", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "你好世界",
      }

      assert.are.equal("你好世界", tostring(prompt.value))
      assert.are.equal(5, prompt.value:pos_char()) -- cursor after last char
    end)


    it("returns UTF-8 value correctly on Enter", function()
      local prompt = Prompt {
        prompt = "Enter: ",
        value = "Hello, 你好 🚀!",
      }

      queue_key(ENTER_KEY, "char")

      local result, status = prompt:run()

      assert.are.equal("Hello, 你好 🚀!", result)
      assert.are.equal("returned", status)
    end)

  end)

end)