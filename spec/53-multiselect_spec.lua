local helpers = require "spec.helpers"


describe("terminal.cli.multiselect", function()

  local MultiSelect

  setup(function()
    helpers.load()
    MultiSelect = require("terminal.cli.multiselect")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("initializes with defaults", function()
      local s = MultiSelect{
        choices = {
          { label = "One" },
          { label = "Two" },
          { label = "Three" },
        },
      }
      assert.are.equal("Select options:", s.prompt)
      assert.are.equal(1, s.selected)
      assert.is_false(s.cancellable)
      assert.is_false(s.clear)
      assert.is_false(s.checked[1])
      assert.is_false(s.checked[2])
      assert.is_false(s.checked[3])
    end)


    it("initializes checked state from value fields", function()
      local s = MultiSelect{
        choices = {
          { label = "A", value = true },
          { label = "B", value = false },
          { label = "C" },
        },
      }
      assert.is_true(s.checked[1])
      assert.is_false(s.checked[2])
      assert.is_false(s.checked[3])
    end)


    it("initializes with all options specified", function()
      local s = MultiSelect{
        choices = { { label = "A" }, { label = "B" } },
        prompt = "Pick some:",
        cancellable = true,
        clear = true,
        checked_sym = "[x] ",
        unchecked_sym = "[ ] ",
      }
      assert.are.equal("Pick some:", s.prompt)
      assert.is_true(s.cancellable)
      assert.is_true(s.clear)
      assert.are.equal("[x] ", s.checked_sym)
      assert.are.equal("[ ] ", s.unchecked_sym)
    end)


    it("respects a custom default cursor position", function()
      local s = MultiSelect{
        choices = { { label = "A" }, { label = "B" }, { label = "C" } },
        default = 3,
      }
      assert.are.equal(3, s.default)
      assert.are.equal(3, s.selected)
    end)


    it("errors when default is not a number", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = "A" } }, default = "first" }
      end, "default must be a number")
    end)


    it("errors when default is out of range", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = "A" }, { label = "B" } }, default = 3 }
      end, "default out of range")
    end)


    it("errors when opts is not a table", function()
      assert.has_error(function()
        MultiSelect("not a table")
      end, "options must be a table")
    end)


    it("errors when choices is not a table", function()
      assert.has_error(function()
        MultiSelect{ choices = "not a table" }
      end, "choices must be a table")
    end)


    it("errors when choices is empty", function()
      assert.has_error(function()
        MultiSelect{ choices = {} }
      end, "choices must not be empty")
    end)


    it("errors when a choice is not a table", function()
      assert.has_error(function()
        MultiSelect{ choices = { "plain string" } }
      end, "each choice must be a table")
    end)


    it("errors when a choice label is not a string", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = 42 } } }
      end, "each choice must have a string label")
    end)


    it("errors when prompt is not a string", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = "A" } }, prompt = 99 }
      end, "prompt must be a string")
    end)


    it("errors when checked_sym is not a string", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = "A" } }, checked_sym = true }
      end, "checked_sym must be a string")
    end)


    it("errors when unchecked_sym is not a string", function()
      assert.has_error(function()
        MultiSelect{ choices = { { label = "A" } }, unchecked_sym = true }
      end, "unchecked_sym must be a string")
    end)

  end)



  describe("height()", function()

    it("returns one row per item when all fit within screen width", function()
      helpers.set_termsize(25, 80)
      local s = MultiSelect{ choices = { { label = "One" }, { label = "Two" } } }
      assert.equals(3, s:height())  -- 1 prompt row + 1 row each for "One" and "Two"
    end)


    it("returns extra rows when items wrap on a narrow screen", function()
      helpers.set_termsize(25, 20)
      local s = MultiSelect{
        prompt = "Select an option for me please:", -- more than 20
        choices = {
          { label = ("a"):rep(30) },
          { label = ("b"):rep(30) },
        },
      }
      assert.equals(6, s:height())
    end)

  end)



  describe("set_selection()", function()

    it("updates the selected index", function()
      local s = MultiSelect{ choices = { { label = "A" }, { label = "B" }, { label = "C" } } }
      s:set_selection(3)
      assert.are.equal(3, s.selected)
    end)


    it("errors when index is not a number", function()
      local s = MultiSelect{ choices = { { label = "A" }, { label = "B" } } }
      assert.has_error(function()
        s:set_selection("one")
      end, "selection index must be a number")
    end)


    it("errors when index is out of range", function()
      local s = MultiSelect{ choices = { { label = "A" }, { label = "B" } } }
      assert.has_error(function()
        s:set_selection(3)
      end, "selection index out of range")
    end)

  end)



  describe("run()", function()

    it("returns a hash table with initial state when Enter pressed", function()
      local s = MultiSelect{
        choices = {
          { label = "Alpha", key = "a", value = true },
          { label = "Beta",  key = "b", value = false },
        },
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.are.equal(true, result["a"])
      assert.are.equal(false, result["b"])
    end)


    it("space toggles the current item on", function()
      local s = MultiSelect{
        choices = {
          { label = "One", key = 1, value = false },
          { label = "Two", key = 2, value = false },
        },
      }
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[1])
      assert.is_false(result[2])
    end)


    it("space toggles the current item off", function()
      local s = MultiSelect{
        choices = { { label = "One", key = "x", value = true } },
      }
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_false(result["x"])
    end)


    it("navigates down and toggles", function()
      local s = MultiSelect{
        choices = {
          { label = "One", key = 1 },
          { label = "Two", key = 2 },
          { label = "Three", key = 3 },
        },
      }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_false(result[1])
      assert.is_true(result[2])
      assert.is_false(result[3])
    end)


    it("does not navigate above the first choice", function()
      local s = MultiSelect{
        choices = { { label = "X", key = "x" }, { label = "Y", key = "y" } },
      }
      helpers.push_kb_input(helpers.keys.up)
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result["x"])
    end)


    it("does not navigate below the last choice", function()
      local s = MultiSelect{
        choices = { { label = "X", key = "x" }, { label = "Y", key = "y" } },
      }
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(helpers.keys.down)
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_false(result["x"])
      assert.is_true(result["y"])
    end)


    it("returns nil and 'cancelled' when Esc pressed with cancellable=true", function()
      local s = MultiSelect{
        choices = { { label = "A" }, { label = "B" } },
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.esc)
      local result, err = s:run()
      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)


    it("treats Ctrl+C as cancel when cancellable=true", function()
      local s = MultiSelect{
        choices = { { label = "A" }, { label = "B" } },
        cancellable = true,
      }
      helpers.push_kb_input(helpers.keys.ctrl_c)
      local result, err = s:run()
      assert.is_nil(result)
      assert.are.equal("cancelled", err)
    end)


    it("ignores Esc when cancellable=false", function()
      local s = MultiSelect{
        choices = { { label = "A", key = "a" }, { label = "B", key = "b" } },
        cancellable = false,
      }
      helpers.push_kb_input(helpers.keys.esc)
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_false(result["a"])
      assert.is_false(result["b"])
    end)


    it("can be invoked directly as a function", function()
      local s = MultiSelect{
        choices = { { label = "Foo", key = "f", value = true } },
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = s()
      assert.is_true(result["f"])
    end)


    it("key defaults to label when not provided", function()
      local s = MultiSelect{
        choices = { { label = "My Option", value = true } },
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result["My Option"])
    end)


    it("supports non-string keys", function()
      local key = {}  -- table as key
      local s = MultiSelect{
        choices = { { label = "A", key = key, value = true } },
      }
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[key])
    end)

  end)



  describe("typeahead", function()

    it("jumps to a matching choice on keypress", function()
      local s = MultiSelect{
        choices = {
          { label = "Apple",  key = 1 },
          { label = "Banana", key = 2 },
          { label = "Cherry", key = 3 },
        },
      }
      helpers.push_kb_input("B")
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_false(result[1])
      assert.is_true(result[2])
      assert.is_false(result[3])
    end)


    it("matches are case-insensitive", function()
      local s = MultiSelect{
        choices = {
          { label = "Apple",  key = 1 },
          { label = "Banana", key = 2 },
        },
      }
      helpers.push_kb_input("b")
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[2])
    end)


    it("accumulates characters to narrow the match", function()
      local s = MultiSelect{
        choices = {
          { label = "Bear",   key = 1 },
          { label = "Banana", key = 2 },
          { label = "Cherry", key = 3 },
        },
      }
      helpers.push_kb_input("b")
      helpers.push_kb_input("a")
      helpers.push_kb_input("n")
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[2])
    end)


    it("does not move when no choice matches the prefix", function()
      local s = MultiSelect{
        choices = {
          { label = "Apple",  key = 1 },
          { label = "Banana", key = 2, value = true },
        },
      }
      s:set_selection(2)
      helpers.push_kb_input("z")
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      -- cursor stayed on Banana (2), space toggled it off
      assert.is_false(result[2])
    end)


    it("wraps around when searching from current position", function()
      local s = MultiSelect{
        choices = {
          { label = "Apple",   key = 1 },
          { label = "Avocado", key = 2 },
          { label = "Banana",  key = 3 },
        },
      }
      s:set_selection(3)
      -- starting at Banana (3), "a" skips it, wraps to Apple (1) before Avocado (2)
      helpers.push_kb_input("a")
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[1])
    end)


    it("space clears the typeahead buffer and toggles the current item", function()
      local s = MultiSelect{
        choices = {
          { label = "Bear",   key = 1 },
          { label = "Banana", key = 2 },
        },
      }
      helpers.push_kb_input("b")   -- jumps to Bear (1)
      helpers.push_kb_input(" ")   -- clears buffer, toggles Bear on
      helpers.push_kb_input("b")   -- fresh search from Bear (1), stays on Bear
      helpers.push_kb_input("a")   -- "ba" matches Banana (2), moves there
      helpers.push_kb_input(" ")   -- clears buffer, toggles Banana on
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[1])
      assert.is_true(result[2])
    end)


    it("backspace removes last typed character and re-searches", function()
      local s = MultiSelect{
        choices = {
          { label = "Bear",   key = 1 },
          { label = "Banana", key = 2 },
          { label = "Cherry", key = 3 },
        },
      }
      helpers.push_kb_input("b")
      helpers.push_kb_input("z")                       -- "bz" → no match, stays on Bear
      helpers.push_kb_input(helpers.keys.backspace)    -- back to "b", remains on Bear
      helpers.push_kb_input("a")                       -- "ba" → matches Banana
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[2])
    end)


    it("backspace is ignored when search buffer is empty", function()
      local s = MultiSelect{
        choices = { { label = "Apple", key = 1 }, { label = "Banana", key = 2 } },
      }
      helpers.push_kb_input(helpers.keys.backspace)
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[1])
    end)


    it("timeout resets the search buffer", function()
      local s = MultiSelect{
        choices = {
          { label = "Bear",   key = 1 },
          { label = "Banana", key = 2 },
          { label = "Cherry", key = 3 },
        },
      }
      helpers.push_kb_input("b")             -- jumps to Bear
      helpers.push_kb_input(nil, "timeout")  -- buffer resets
      helpers.push_kb_input("c")             -- searches from Bear (current) → Cherry
      helpers.push_kb_input(" ")
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[3])
    end)


    it("arrow key resets the search buffer", function()
      local s = MultiSelect{
        choices = {
          { label = "Apple",  key = 1 },
          { label = "Banana", key = 2 },
          { label = "Cherry", key = 3 },
        },
      }
      helpers.push_kb_input("b")              -- jumps to Banana (2)
      helpers.push_kb_input(helpers.keys.up)  -- resets buffer, moves up to Apple (1)
      helpers.push_kb_input(" ")              -- toggles Apple
      helpers.push_kb_input(helpers.keys.enter)
      local result = s:run()
      assert.is_true(result[1])
    end)

  end)

end)
