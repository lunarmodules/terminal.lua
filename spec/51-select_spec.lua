local helpers = require "spec.helpers"


describe("terminal.cli.select", function()

  local Select

  setup(function()
    helpers.load()
    Select = require("terminal.cli.select")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("initializes with defaults", function()
      local s = Select{
        choices = { "One", "Two", "Three" },
      }
      assert.are.equal("Select an option:", s.prompt)
      assert.are.equal(1, s.default)
      assert.are.equal(1, s.selected)
      assert.is_false(s.cancellable)
      assert.is_false(s.clear)
    end)


    it("initializes with all options specified", function()
      local s = Select{
        choices = { "A", "B", "C" },
        prompt = "Pick one:",
        default = 2,
        cancellable = true,
        clear = true,
      }
      assert.are.equal("Pick one:", s.prompt)
      assert.are.equal(2, s.default)
      assert.are.equal(2, s.selected)
      assert.is_true(s.cancellable)
      assert.is_true(s.clear)
    end)


    it("errors when opts is not a table", function()
      assert.has_error(function()
        Select("not a table")
      end, "options must be a table")
    end)


    it("errors when choices is not a table", function()
      assert.has_error(function()
        Select{ choices = "not a table" }
      end, "choices must be a table")
    end)


    it("errors when choices is empty", function()
      assert.has_error(function()
        Select{ choices = {} }
      end, "choices must not be empty")
    end)


    it("errors when a choice is not a string", function()
      assert.has_error(function()
        Select{ choices = { "ok", 42 } }
      end, "each choice must be a string")
    end)


    it("errors when default is not a number", function()
      assert.has_error(function()
        Select{ choices = { "A" }, default = "first" }
      end, "default must be a number")
    end)


    it("errors when default is below range", function()
      assert.has_error(function()
        Select{ choices = { "A", "B" }, default = 0 }
      end, "default out of range")
    end)


    it("errors when default is above range", function()
      assert.has_error(function()
        Select{ choices = { "A", "B" }, default = 3 }
      end, "default out of range")
    end)


    it("errors when prompt is not a string", function()
      assert.has_error(function()
        Select{ choices = { "A" }, prompt = 99 }
      end, "prompt must be a string")
    end)

  end)



  describe("height()", function()

    it("returns one row per item when all fit within screen width", function()
      helpers.set_termsize(25, 80)
      local s = Select{ choices = { "One", "Two" } }
      assert.equals(3, s:height())  -- 1 prompt row + 1 row each for "One" and "Two"
    end)


    it("returns extra rows when items wrap on a narrow screen", function()
      helpers.set_termsize(25, 20)
      local s = Select{
        prompt = "Select an option for me please:", -- more than 20
        choices = {
          ("a"):rep(30),
          ("b"):rep(30),
        },
      }
      assert.equals(6, s:height())
    end)

  end)



  describe("set_selection()", function()

    it("updates the selected index", function()
      local s = Select{ choices = { "A", "B", "C" } }
      s:set_selection(3)
      assert.are.equal(3, s.selected)
    end)


    it("errors when index is not a number", function()
      local s = Select{ choices = { "A", "B" } }
      assert.has_error(function()
        s:set_selection("one")
      end, "selection index must be a number")
    end)


    it("errors when index is out of range", function()
      local s = Select{ choices = { "A", "B" } }
      assert.has_error(function()
        s:set_selection(3)
      end, "selection index out of range")
    end)

  end)



  describe("run()", function()

    it("returns default index and value when Enter pressed", function()
      local s = Select{
        choices = { "Alpha", "Beta", "Gamma" },
        default = 2,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local idx, val = s:run()
      assert.are.equal(2, idx)
      assert.are.equal("Beta", val)
    end)


    it("returns index and value after navigating down", function()
      local s = Select{ choices = { "One", "Two", "Three" } }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(helpers.keys.enter)
      local idx, val = s:run()
      assert.are.equal(2, idx)
      assert.are.equal("Two", val)
    end)


    it("does not navigate above the first choice", function()
      local s = Select{ choices = { "X", "Y" }, default = 1 }
      helpers.push_kb_input(helpers.keys.up)
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(1, idx)
    end)


    it("does not navigate below the last choice", function()
      local s = Select{ choices = { "X", "Y" }, default = 2 }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)


    it("returns nil and 'cancelled' when Esc pressed with cancellable=true", function()
      local s = Select{
        choices = { "A", "B" },
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local idx, err = s:run()
      assert.is_nil(idx)
      assert.are.equal("cancelled", err)
    end)


    it("treats Ctrl+C as cancel when cancellable=true", function()
      local s = Select{
        choices = { "A", "B" },
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.ctrl_c)
      local idx, err = s:run()
      assert.is_nil(idx)
      assert.are.equal("cancelled", err)
    end)


    it("ignores Esc when cancellable=false", function()
      local s = Select{
        choices = { "A", "B" },
        cancellable = false,
      }
      helpers.push_kb_input(helpers.keys.esc)
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(1, idx)
    end)


    it("can be invoked directly as a function", function()
      local s = Select{
        choices = { "Foo", "Bar" },
        default = 1,
      }
      helpers.push_kb_input(helpers.keys.enter)
      local idx, val = s()
      assert.are.equal(1, idx)
      assert.are.equal("Foo", val)
    end)

  end)



  describe("typeahead", function()

    it("jumps to a matching choice on keypress", function()
      local s = Select{ choices = { "Apple", "Banana", "Cherry" } }
      helpers.push_kb_input("B")
      helpers.push_kb_input(helpers.keys.enter)
      local idx, val = s:run()
      assert.are.equal(2, idx)
      assert.are.equal("Banana", val)
    end)


    it("matches are case-insensitive", function()
      local s = Select{ choices = { "Apple", "Banana", "Cherry" } }
      helpers.push_kb_input("b")
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)


    it("accumulates characters to narrow the match", function()
      local s = Select{ choices = { "Bear", "Banana", "Cherry" } }
      helpers.push_kb_input("b")
      helpers.push_kb_input("a")
      helpers.push_kb_input("n")
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)


    it("does not move when no choice matches the prefix", function()
      local s = Select{ choices = { "Apple", "Banana", "Cherry" }, default = 2 }
      helpers.push_kb_input("z")
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)


    it("wraps around when searching from current position", function()
      local s = Select{ choices = { "Apple", "Avocado", "Banana" }, default = 3 }
      -- starting at Banana (3), "a" skips it, wraps to Apple (1) before Avocado (2)
      helpers.push_kb_input("a")
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(1, idx)
    end)


    it("backspace removes last typed character and re-searches", function()
      local s = Select{ choices = { "Bear", "Banana", "Cherry" } }
      helpers.push_kb_input("b")
      helpers.push_kb_input("z")        -- "bz" → no match, stays on Bear
      helpers.push_kb_input(helpers.keys.backspace)  -- back to "b", remains on Bear
      helpers.push_kb_input("a")        -- "ba" → matches Banana
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)


    it("backspace is ignored when search buffer is empty", function()
      local s = Select{ choices = { "Apple", "Banana" }, default = 1 }
      helpers.push_kb_input(helpers.keys.backspace)
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(1, idx)
    end)


    it("timeout resets the search buffer", function()
      local s = Select{ choices = { "Bear", "Banana", "Cherry" } }
      helpers.push_kb_input("b")        -- jumps to Bear
      helpers.push_kb_input(nil, "timeout")  -- buffer resets
      helpers.push_kb_input("c")        -- now searches from Bear (current) → Cherry
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(3, idx)
    end)


    it("arrow key resets the search buffer", function()
      local s = Select{ choices = { "Apple", "Banana", "Cherry" }, default = 1 }
      helpers.push_kb_input("b")        -- jumps to Banana (index 2)
      helpers.push_kb_input(helpers.keys.up)  -- resets buffer, moves up to index 1
      helpers.push_kb_input("a")        -- searches from Apple (current) → stays on Apple since it matches "a"
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(1, idx)
    end)


    it("inclusive start: current choice matches its own prefix", function()
      local s = Select{ choices = { "Apple", "Avocado", "Banana" }, default = 2 }
      -- "av" matches "Avocado" which is current selection → stays
      helpers.push_kb_input("a")
      helpers.push_kb_input("v")
      helpers.push_kb_input(helpers.keys.enter)
      local idx = s:run()
      assert.are.equal(2, idx)
    end)

  end)

end)
