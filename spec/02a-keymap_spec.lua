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
      assert.is.equal("null", keymap.default_key_map["\000"])
    end)

  end)



  describe("default_keys", function()

    it("is a table mapping names to internal names", function()
      assert.is.table(keymap.default_keys)
      assert.is.equal("null", keymap.default_keys.null)
    end)


    it("contains the default aliasses", function()
      assert.is.equal("bs", keymap.default_keys.backspace)
      assert.is.equal("ht", keymap.default_keys.tab)
    end)


    it("looks keys up case-insensitive", function()
      -- not in the table to begin with
      assert.is_nil(rawget(keymap.default_keys, "NULL")) -- default key
      assert.is_nil(rawget(keymap.default_keys, "tAB"))    -- default alias

      -- lookup works, and sets them
      assert.is.equal("null", keymap.default_keys.NULL) -- default key
      assert.is.equal("ht", keymap.default_keys.tAB)    -- default alias

      -- metamethod sets them on the table, after the first lookup
      assert.is.equal("null", rawget(keymap.default_keys, "NULL")) -- default key
      assert.is.equal("ht", rawget(keymap.default_keys, "tAB"))    -- default alias
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
      assert.is.equal("null", km["\000"])
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

      assert.is.equal("null", keys["null"])       -- default key
      assert.is.equal("bs", keys["backspace"])    -- default alias
      assert.is.equal("ht", keys["tab"])          -- default alias
    end)


    it("adds the provided aliasses", function()
      local keys = keymap.get_keys(nil, {
        sooper_key = keymap.default_keys.esc,
      })

      assert.is.equal("esc", keys.sooper_key)
    end)


    it("looks keys up case-insensitive", function()
      local keys = keymap.get_keys(nil, {
        sooper_key = keymap.default_keys.esc,
      })

      -- not in the table to begin with
      assert.is_nil(rawget(keys, "NULL"))       -- default key
      assert.is_nil(rawget(keys, "tAB"))        -- default alias
      assert.is_nil(rawget(keys, "SoOpEr_KeY")) -- custom alias

      -- lookup works, and sets them
      assert.is.equal("null", keys.NULL) -- default key
      assert.is.equal("ht", keys.tAB)    -- default alias
      assert.is.equal("esc", keys.SoOpEr_KeY) -- custom alias

      -- metamethod sets them on the table, after the first lookup
      assert.is.equal("null", rawget(keys, "NULL")) -- default key
      assert.is.equal("ht", rawget(keys, "tAB"))    -- default alias
      assert.is.equal("esc", rawget(keys, "SoOpEr_KeY")) -- custom alias
    end)


    it("throws an error if not found", function()
      local km = keymap.get_keys()
      assert.has.error(function()
        return km["unknown_key"]
      end, "Unknown key-name: unknown_key")
    end)

  end)

end)
