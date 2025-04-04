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
  end)


  lazy_teardown(function()
    sys._readkey = old_readkey
  end)


  before_each(function()
    keyboard_buffer = ""
    t = require("terminal")
  end)


  after_each(function()
    -- forcefully unload module
    for mod in pairs(package.loaded) do
      if mod:match("^terminal") then
        package.loaded[mod] = nil
      end
    end
  end)




  describe("sys_readansi()", function()

    it("matches system.readansi()", function()
      assert.are.equal(sys.readansi, t.input.sys_readansi)
    end)

  end)



  describe("readansi()", function()

    it("uses the sleep function set", function()
      local called = false
      local old_sleep = t._sleep
      t._asleep = function() called = true end
      finally(function()
        t._asleep = old_sleep
      end)

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



  describe("read_query_answer()", function()

    -- returns an ANSWER sequence to the cursor-position query
    local add_cpos = function(row, col)
      keyboard_buffer = keyboard_buffer .. ("\027[%d;%dR"):format(row, col)
    end

    local cursor_answer_pattern = "^\27%[(%d+);(%d+)R$"


    it("returns the cursor positions read", function()
      add_cpos(12, 34)
      add_cpos(56, 78)
      assert.are.same({{"12", "34"},{"56", "78"}}, t.input.read_query_answer(cursor_answer_pattern, 2))
    end)


    it("leaves other 'char' input in the buffers", function()
      keyboard_buffer = "abc"
      add_cpos(12, 34)
      keyboard_buffer = keyboard_buffer .. "123"
      assert.are.same({{"12", "34"}}, t.input.read_query_answer(cursor_answer_pattern, 1))
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
      assert.are.same({{"12", "34"},{"56", "78"}}, t.input.read_query_answer(cursor_answer_pattern, 2))
      assert.are.equal("\027[90;12R", keyboard_buffer)
      local binstring = require("luassert.formatters.binarystring")
      assert:add_formatter(binstring)
      local r = {t.input.readansi(0)}
      assert.equal("\27[8;10;80t", r[1])
      assert.equal("ansi", r[2])
      assert.is_nil(r[3])
    end)

  end)



  describe("query()", function()

    it("makes the right calls in the right order", function()
      local res = {}
      t.input.preread = function(...) table.insert(res, { "preread", ... } ) end
      t.output.write = function(...) table.insert(res, { "write", ... } ) end
      t.output.flush = function(...) table.insert(res, { "flush", ... } ) end
      t.input.read_query_answer = function(...) table.insert(res, { "read_query_answer", ... } ) end

      t.input.query("query", "answer_pattern")

      assert.are.same({
        { "preread" },
        { "write", "query" },
        { "flush" },
        { "read_query_answer", "answer_pattern", 1 },
      }, res)
    end)

  end)


end)
