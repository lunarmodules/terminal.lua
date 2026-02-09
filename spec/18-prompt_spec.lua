--- Tests for terminal.cli.prompt edge cases
-- Covers: empty value, cancelled/returned behavior

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
        return entry.key, entry.keytype
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
  -- @param key string: the key character or escape sequence
  -- @param keytype string: the type of key (e.g., "char", "ansi")
  local function queue_key(key, keytype)
    assert(type(key) == "string", "queue_key: 'key' must be a string, got " .. type(key))
    assert(type(keytype) == "string", "queue_key: 'keytype' must be a string, got " .. type(keytype))
    table.insert(input_queue, { key = key, keytype = keytype })
  end

  -- Derive the Enter key from the keymap (same as production code)
  local keymap_module = require("terminal.input.keymap")
  local keys = keymap_module.default_keys
  local default_key_map = keymap_module.default_key_map

  -- Find the raw key that maps to the "enter" key name
  local ENTER_KEY
  for raw_key, key_name in pairs(default_key_map) do
    if key_name == keys.enter then
      ENTER_KEY = raw_key
      break
    end
  end
  assert(ENTER_KEY, "Could not find Enter key in keymap")

  -- Find the raw key that maps to the "escape" key name
  local ESC_KEY
  for raw_key, key_name in pairs(default_key_map) do
    if key_name == keys.escape then
      ESC_KEY = raw_key
      break
    end
  end
  assert(ESC_KEY, "Could not find Escape key in keymap")

  -- Find the raw key that maps to the "ctrl_c" key name (Ctrl+C)
  local CTRL_C_KEY
  for raw_key, key_name in pairs(default_key_map) do
    if key_name == keys.ctrl_c then
      CTRL_C_KEY = raw_key
      break
    end
  end
  assert(CTRL_C_KEY, "Could not find Ctrl+C key in keymap")



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
      queue_key(ESC_KEY, "ansi")

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
      queue_key(CTRL_C_KEY, "char")

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
      queue_key(ENTER_KEY, "char")

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
      queue_key(ENTER_KEY, "char")

      local result, err = prompt:run()

      assert.are.equal("", result)
      assert.is_nil(err)
    end)

  end)

end)