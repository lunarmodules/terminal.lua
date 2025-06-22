describe("keymap:", function()

  local keymap

  lazy_setup(function()
    keymap = require("terminal.input.keymap")
  end)


  lazy_teardown(function()
    keymap = nil
  end)



  describe("default_key_map", function()

    it("is a table containing key mappings", function()
      assert.is.table(keymap.default_key_map)
      assert.is.equal("ctrl_@", keymap.default_key_map["\000"])
    end)

  end)



  describe("default_keys", function()

    it("is a table mapping names to internal names", function()
      assert.is.table(keymap.default_keys)
      assert.is.equal("ctrl_@", keymap.default_keys.null)
    end)


    it("contains the default aliasses", function()
      assert.is.equal("ctrl_h", keymap.default_keys.backspace)
      assert.is.equal("ctrl_i", keymap.default_keys.tab)
    end)


    it("throws an error if not found", function()
      assert.has.error(function()
        return keymap.default_keys["unknown_key"]
      end, "Unknown key-name: unknown_key")
    end)

  end)



  describe("get_keymap()", function()

    it("returns a copy, and not the default keymap", function()
      local keymap1 = keymap.get_keymap()
      local keymap2 = keymap.get_keymap()

      assert.is_not.equal(keymap1, keymap2)
      assert.is_not.equal(keymap1, keymap.default_key_map)
      assert.is_not.equal(keymap2, keymap.default_key_map)
    end)


    it("returns a table containing the default key mappings", function()
      local km = keymap.get_keymap()
      assert.is.equal("ctrl_@", km["\000"])
    end)


    it("adds the overrides provided", function()
      -- vim keys up/down
      local km = keymap.get_keymap({
        ["j"] = keymap.default_keys.down,
        ["k"] = keymap.default_keys.up,
      })

      assert.is.equal("down", km["j"])
      assert.is.equal("up", km["k"])
    end)

  end)



  describe("get_keys()", function()

    it("returns a copy, and not the default keys", function()
      local keys1 = keymap.get_keys()
      local keys2 = keymap.get_keys()

      assert.is_not.equal(keys1, keys2)
      assert.is_not.equal(keys1, keymap.default_keys)
      assert.is_not.equal(keys2, keymap.default_keys)
    end)


    it("returns a table containing the default keys and default aliasses", function()
      local keys = keymap.get_keys()

      assert.is.equal("ctrl_@", keys["null"])       -- default key
      assert.is.equal("ctrl_h", keys["backspace"])    -- default alias
      assert.is.equal("ctrl_i", keys["tab"])          -- default alias
    end)


    it("adds the provided aliasses", function()
      local keys = keymap.get_keys(nil, {
        sooper_key = keymap.default_keys.esc,
      })

      assert.is.equal("ctrl_[", keys.sooper_key)
    end)


    it("throws an error if not found", function()
      local km = keymap.get_keys()
      assert.has.error(function()
        return km["unknown_key"]
      end, "Unknown key-name: unknown_key")
    end)

  end)



  describe("is_printable()", function()

    it("returns true for printable characters", function()
      assert.is_true(keymap.is_printable("a"))
      assert.is_true(keymap.is_printable("1"))
      assert.is_true(keymap.is_printable(" "))
      -- add some utf8 chars
      assert.is_true(keymap.is_printable("é"))
      assert.is_true(keymap.is_printable("😊"))
    end)


    it("returns false for non-printable characters", function()
      assert.is_false(keymap.is_printable("\n"))
      assert.is_false(keymap.is_printable("\r"))
      assert.is_false(keymap.is_printable("\t"))
      assert.is_false(keymap.is_printable("\000")) -- null character
      assert.is_false(keymap.is_printable("\027")) -- escape character
      assert.is_false(keymap.is_printable("\027OP")) -- ansi sequence for F1 key
    end)

  end)

end)
