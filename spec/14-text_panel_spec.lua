local TextPanel = require("terminal.ui.panel.text_panel")
local terminal = require("terminal")

describe("terminal.ui.panel.text_panel", function()

  setup(function()
    TextPanel = require("terminal.ui.panel.text_panel")
    terminal = require("terminal")
    text = require("terminal.text")

    -- Mock terminal functions
    terminal.cursor = {
      position = {
        set = function(row, col) end,
        set_seq = function(row, col) return "pos_seq" end,
        backup_seq = function() return "backup_seq" end,
        restore_seq = function() return "restore_seq" end
      }
    }
    terminal.output = {
      write = function(text) end
    }
    terminal.text = {
      stack = {
        push_seq = function(attr) return "push_seq" end,
        pop_seq = function() return "pop_seq" end
      }
    }
  end)


  teardown(function()
    TextPanel = nil
    terminal = nil -- luacheck: ignore
    text = nil
  end)


  describe("init()", function()

    it("creates a text panel with default values", function()
      local panel = TextPanel {}

      assert.are.same({}, panel.lines)
      assert.are.equal(1, panel.scroll_step)
      assert.are.equal(1, panel.position)
    end)


    it("creates a text panel with custom values", function()
      local lines = {"Line 1", "Line 2", "Line 3"}
      local panel = TextPanel {
        lines = lines,
        scroll_step = 3,
        initial_position = 2
      }

      assert.are.same(lines, panel.lines)
      assert.are.equal(3, panel.scroll_step)
      assert.are.equal(2, panel.position)
    end)


    it("provides content callback for parent constructor", function()
      local panel = TextPanel { lines = {"test"} }

      assert.is_function(panel.content)
    end)

  end)


  describe("_truncate_line()", function()

    it("returns empty string for nil input", function()
      local panel = TextPanel {}
      local result = panel:_truncate_line(nil, 10)

      assert.are.equal("", result)
    end)


    it("returns empty string for empty input", function()
      local panel = TextPanel {}
      local result = panel:_truncate_line("", 10)

      assert.are.equal("", result)
    end)


    it("returns original line if it fits", function()
      local panel = TextPanel {}
      local result = panel:_truncate_line("short", 10)

      assert.are.equal("short", result)
    end)


    it("truncates line if too long", function()
      local panel = TextPanel {}
      local result = panel:_truncate_line("very long line", 5)

      assert.is_true(text.width.utf8swidth(result) <= 5)
      assert.are.equal("very ", result)
    end)

  end)


  describe("go_to()", function()

    it("goes to specified position", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"} }

      panel:go_to(3)

      assert.are.equal(3, panel.position)
    end)


    it("clamps position to valid range", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      panel:go_to(0)
      assert.are.equal(1, panel.position)

      panel:go_to(10)
      assert.are.equal(3, panel.position)
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      local render_called = false
      panel.render = function() render_called = true end

      panel:go_to(2) -- Change position first
      assert.is_true(render_called)

      render_called = false
      panel:go_to(2) -- Same position
      assert.is_false(render_called)
    end)

  end)


  describe("scroll_up()", function()

    it("scrolls up by scroll_step", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"}, scroll_step = 2 }

      panel:go_to(5)
      panel:scroll_up()

      assert.are.equal(3, panel.position)
    end)


    it("does not scroll below 1", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, scroll_step = 5 }

      panel:go_to(2)
      panel:scroll_up()

      assert.are.equal(1, panel.position)
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      local render_called = false
      panel.render = function() render_called = true end

      panel:scroll_up() -- Already at 1
      assert.is_false(render_called)
    end)

  end)


  describe("scroll_down()", function()

    it("scrolls down by scroll_step", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"}, scroll_step = 2 }

      panel:go_to(1)
      panel:scroll_down()

      assert.are.equal(3, panel.position)
    end)


    it("does not scroll beyond last line", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, scroll_step = 5 }

      panel:go_to(2)
      panel:scroll_down()

      assert.are.equal(3, panel.position)
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      local render_called = false
      panel.render = function() render_called = true end

      panel:go_to(3) -- At last line
      render_called = false -- Reset after go_to call
      panel:scroll_down()
      assert.is_false(render_called)
    end)

  end)


  describe("get_position()", function()

    it("returns current position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      panel:go_to(2)

      assert.are.equal(2, panel:get_position())
    end)

  end)


  describe("get_line_count()", function()

    it("returns number of lines", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d"} }

      assert.are.equal(4, panel:get_line_count())
    end)


    it("returns 0 for empty lines", function()
      local panel = TextPanel { lines = {} }

      assert.are.equal(0, panel:get_line_count())
    end)

  end)


  describe("set_lines()", function()

    it("sets new lines and resets position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      panel:go_to(3)
      panel:set_lines({"x", "y"})

      assert.are.same({"x", "y"}, panel.lines)
      assert.are.equal(1, panel.position)
    end)


    it("handles nil input", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      panel:set_lines(nil)

      assert.are.same({}, panel.lines)
      assert.are.equal(1, panel.position)
    end)

  end)


  describe("add_line()", function()

    it("adds line to end", function()
      local panel = TextPanel { lines = {"a", "b"} }

      panel:add_line("c")

      assert.are.same({"a", "b", "c"}, panel.lines)
    end)


    it("handles nil input", function()
      local panel = TextPanel { lines = {"a", "b"} }

      panel:add_line(nil)

      assert.are.same({"a", "b", ""}, panel.lines)
    end)

  end)


  describe("clear()", function()

    it("clears all lines and resets position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      panel:go_to(3)
      panel:clear()

      assert.are.same({}, panel.lines)
      assert.are.equal(1, panel.position)
    end)

  end)

end)
