local helpers = require "spec.helpers"


describe("input:", function()

  local t

  before_each(function()
    t = helpers.load()
  end)


  after_each(function()
    helpers.unload()
  end)




  describe("sys_readansi()", function()

    it("matches system.readansi()", function()
      local sys = require("system")
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
      helpers.push_kb_input("a")
      assert.are.equal("a", t.input.readansi(0.01))
    end)


    it("reads from the buffer first", function()
      helpers.push_kb_input("a")
      t.input.push_input("b", "key", nil)
      assert.are.equal("b", t.input.readansi(0.01))
      assert.are.equal("a", t.input.readansi(0.01))
    end)

  end)



  describe("preread()", function()

    it("empties the keyboard-buffer into the preread-buffer", function()
      helpers.push_kb_input("abc")
      t.input.preread()
      assert.are.equal("a", t.input.readansi(0.01))
      assert.are.equal("b", t.input.readansi(0.01))
      assert.are.equal("c", t.input.readansi(0.01))
      assert.are.same({nil, "timeout"}, {t.input.readansi(0)})
    end)

  end)



  describe("read_query_answer()", function()

    local add_cpos
    local cursor_answer_pattern

    setup(function()
      -- returns an ANSWER sequence to the cursor-position query
      add_cpos = function(row, col)
        helpers.push_kb_input(("\027[%d;%dR"):format(row, col))
      end
      cursor_answer_pattern = "^\27%[(%d+);(%d+)R$"
    end)



    it("returns the cursor positions read", function()
      add_cpos(12, 34)
      add_cpos(56, 78)
      assert.are.same({{"12", "34"},{"56", "78"}}, t.input.read_query_answer(cursor_answer_pattern, 2))
    end)


    it("leaves other 'char' input in the buffers", function()
      helpers.push_kb_input("abc")
      add_cpos(12, 34)
      helpers.push_kb_input("123")
      assert.are.same({{"12", "34"}}, t.input.read_query_answer(cursor_answer_pattern, 1))
      assert.are.equal("a", t.input.readansi(0))
      assert.are.equal("b", t.input.readansi(0))
      assert.are.equal("c", t.input.readansi(0))
      assert.are.equal("1", t.input.readansi(0))
      assert.are.equal("2", t.input.readansi(0))
      assert.are.equal("3", t.input.readansi(0))
    end)


    it("leaves other 'ansi' input in the buffers", function()
      helpers.push_kb_input("\27[8;10;80t\027[12;34R\027[56;78R\027[90;12R")
      assert.are.same({{"12", "34"},{"56", "78"}}, t.input.read_query_answer(cursor_answer_pattern, 2))
      local binstring = require("luassert.formatters.binarystring")
      assert:add_formatter(binstring)
      local r = {t.input.readansi(0)}
      assert.equal("\27[8;10;80t", r[1])
      assert.equal("ansi", r[2])
      assert.is_nil(r[3])
    end)


    it("returns nil and error message on timeout without throwing", function()
      helpers.push_kb_input(nil, "timeout")

      local result, err = t.input.read_query_answer(cursor_answer_pattern, 1)

      assert.is_nil(result)
      assert.are.equal("timeout: no response from terminal", err)
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


    it("returns nil and error when read_query_answer times out", function()
      t.input.preread = function() end
      helpers.push_kb_input(nil, "timeout")

      local result, err = t.input.query("\27[6n", "^\27%[(%d+);(%d+)R$")

      assert.is_nil(result)
      assert.are.equal("timeout: no response from terminal", err)
    end)

  end)

end)
