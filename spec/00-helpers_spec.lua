describe("Spec helpers", function()

  local helpers

  setup(function()
    helpers = require("spec.helpers")
  end)



  describe("(un)loading", function()

    it("removes terminal and system from package.loaded", function()
      helpers.load()
      assert.is_not_nil(package.loaded["terminal"])
      helpers.unload()
      assert.is_nil(package.loaded["terminal"])
      assert.is_nil(package.loaded["system"])
    end)


    it("reloads terminal after unload", function()
      helpers.unload()
      local _ = helpers.load()
      assert.is_not_nil(package.loaded["terminal"])
      helpers.unload()
      assert.is_nil(package.loaded["terminal"])
      local t2 = helpers.load()
      assert.is_table(t2)
      assert.is_not_nil(package.loaded["terminal"])
    end)


    it("returns terminal module with expected API", function()
      helpers.unload()
      local terminal = helpers.load()
      assert.is_table(terminal.input)
    end)


    it("returns a fresh terminal table on reload", function()
      helpers.unload()
      local t1 = helpers.load()
      helpers.unload()
      local t2 = helpers.load()
      assert.is_table(t2)
      assert.is_table(t2.utils)
      assert.is_table(t2.input)
      assert.not_equal(t1, t2)
    end)

  end)



  describe("termsize", function()

    it("defaults to 25x80", function()
      helpers.load()

      local rows, cols = helpers.get_termsize()
      assert.equals(25, rows)
      assert.equals(80, cols)
    end)


    it("patches system.termsize to use mocked values", function()
      helpers.load()

      helpers.set_termsize(30, 90)

      local system = require("system")
      local rows, cols = system.termsize()
      assert.equals(30, rows)
      assert.equals(90, cols)
    end)

  end)


  describe("keyboard input mock", function()

    it("returns bytes from the helper _readkey buffer", function()
      helpers.load()

      helpers._push_input("ab")

      local b1 = helpers._readkey()
      local b2 = helpers._readkey()
      local b3 = helpers._readkey()

      assert.equals(string.byte("a"), b1)
      assert.equals(string.byte("b"), b2)
      assert.is_nil(b3)
    end)


    it("returns nil and error when pushing an error entry", function()
      helpers.load()

      helpers._push_input(nil, "some-error")

      local b, err = helpers._readkey()
      assert.is_nil(b)
      assert.equals("some-error", err)
    end)


    it("patches system._readkey to use the mock buffer", function()
      helpers.load()

      helpers._push_input("X")

      local system = require("system")
      local b = system._readkey()

      assert.equals(string.byte("X"), b)
    end)


    it("terminal.input.readansi() returns data read from the mock buffer", function()
      local terminal = helpers.load()

      helpers._push_input("X")

      local rawkey, keytype = terminal.input.readansi(0.01)
      assert.equals("X", rawkey)
      assert.equals("char", keytype)
    end)

  end)

end)
