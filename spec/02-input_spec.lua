describe("input:", function()

  local t, sys, old_readkey
  local keyboard_buffer = ""

  lazy_setup(function()
    sys = require("system")

    -- patch low level readkey, such that it won't block during tests
    old_readkey = sys._readkey
    sys._readkey = function()
      if keyboard_buffer == "" then
        return nil
      end
      local char = keyboard_buffer:sub(1, 1)
      keyboard_buffer = keyboard_buffer:sub(2)
      return string.byte(char)
    end

    t = require("terminal")
  end)


  lazy_teardown(function()
    sys._readkey = old_readkey
  end)


  before_each(function()
    keyboard_buffer = ""
  end)



  describe("sys_readansi()", function()

    it("matches system.readansi()", function()
      assert.are.equal(sys.readansi, t.input.sys_readansi)
    end)

  end)



  describe("set_sleep()", function()

    after_each(function()
      t.input.set_sleep(sys.sleep) -- restore the old function
    end)


    it("sets the default sleep function", function()
      local called = false
      local newsleep = function() called = true end

      t.input.set_sleep(newsleep)
      t.input.readansi(0.01)
      assert.is_true(called)
    end)


    it("throws an error if the argument is not a function", function()
      assert.has_error(function()
        t.input.set_sleep("not a function")
      end)
    end)

  end)



  describe("setbsleep()", function()

    pending("todo", function()
      -- TODO: implement
    end)

  end)



  describe("readansi()", function()

    it("uses the sleep function set", function()
      local called = false
      local newsleep = function() called = true end

      t.input.set_sleep(newsleep)
      t.input.readansi(0.01)
      assert.is_true(called)
    end)


    it("reads a single character", function()
      keyboard_buffer = "a"
      assert.are.equal("a", t.input.readansi(0.01))
    end)


    it("reads from the buffer first", function()
      keyboard_buffer = "a"
      t.input.push_input("b", "key", nil)
      assert.are.equal("b", t.input.readansi(0.01))
      assert.are.equal("a", t.input.readansi(0.01))
    end)

  end)



  describe("preread()", function()

    it("empties the keyboard-buffer into the preread-buffer", function()
      keyboard_buffer = "abc"
      t.input.preread()
      assert.are.equal("", keyboard_buffer)

      assert.are.equal("a", t.input.readansi(0.01))
      assert.are.equal("b", t.input.readansi(0.01))
      assert.are.equal("c", t.input.readansi(0.01))
      assert.are.same({nil, "timeout"}, {t.input.readansi(0)})
    end)

  end)



  describe("read_cursor_pos()", function()

    it("accepts only numbers as input", function()
      assert.has_error(function()
        t.input.read_cursor_pos("a")
      end)
    end)


    it("returns the cursor positions read", function()
      keyboard_buffer = "\027[12;34R\027[56;78R"
      assert.are.same({{12, 34},{56, 78}}, t.input.read_cursor_pos(2))
    end)


    it("leaves other 'char' input in the buffers", function()
      keyboard_buffer = "abc\027[12;34R123"
      assert.are.same({{12, 34}}, t.input.read_cursor_pos(1))
      assert.are.equal("123", keyboard_buffer)
      assert.are.equal("a", t.input.readansi(0))
      assert.are.equal("b", t.input.readansi(0))
      assert.are.equal("c", t.input.readansi(0))
      assert.are.equal("1", t.input.readansi(0))
      assert.are.equal("2", t.input.readansi(0))
      assert.are.equal("3", t.input.readansi(0))
    end)


    it("leaves other 'ansi' input in the buffers", function()
      keyboard_buffer = "\27[8;10;80t\027[12;34R\027[56;78R\027[90;12R"
      assert.are.same({{12, 34},{56, 78}}, t.input.read_cursor_pos(2))
      assert.are.equal("\027[90;12R", keyboard_buffer)
      local binstring = require("luassert.formatters.binarystring")
      assert:add_formatter(binstring)
      local r = {t.input.readansi(0)}
      assert.equal("\27[8;10;80t", r[1])
      assert.equal("ansi", r[2])
      assert.is_nil(r[3])
    end)

  end)

end)
