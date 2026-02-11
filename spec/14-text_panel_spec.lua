local helpers = require "spec.helpers"


describe("terminal.ui.panel.text", function()

  local TextPanel
  local terminal
  local text

  setup(function()
    terminal = helpers.load()
    TextPanel = require("terminal.ui.panel.text")
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
    terminal.clear = {
      box = function(row, col, height, width) end,
      box_seq = function(row, col, height, width) return "clear_seq" end,
      eol_seq = function() return "eol_seq" end
    }
  end)


  teardown(function()
    TextPanel = nil
    terminal = nil -- luacheck: ignore
    text = nil
    helpers.unload()
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



  describe("format_line_truncate()", function()

    it("returns padded string for nil input", function()
      local panel = TextPanel {}
      local result = panel:format_line_truncate(nil, 10)

      assert.are.equal("          ", result[1]) -- 10 spaces
    end)


    it("returns padded string for empty input", function()
      local panel = TextPanel {}
      local result = panel:format_line_truncate("", 10)

      assert.are.equal("          ", result[1]) -- 10 spaces
    end)


    it("returns padded line if it fits", function()
      local panel = TextPanel {}
      local result = panel:format_line_truncate("short", 10)

      assert.are.equal("short     ", result[1]) -- "short" + 5 spaces
    end)


    it("truncates line if too long", function()
      local panel = TextPanel {}
      local result = panel:format_line_truncate("very long line", 5)

      assert.is_true(text.width.utf8swidth(result[1]) <= 5)
      assert.are.equal("very ", result[1])
    end)

  end)



  describe("set_position()", function()

    it("goes to specified position", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)

      panel:set_position(3)

      assert.are.equal(3, panel.position)
    end)


    it("clamps position to valid range", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)

      panel:set_position(0)
      assert.are.equal(1, panel.position)

      panel:set_position(10)
      assert.are.equal(2, panel.position) -- max position is 3-2+1=2
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = true }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_position(2) -- Change position first
      assert.is_true(render_called)

      render_called = false
      panel:set_position(2) -- Same position
      assert.is_false(render_called)
    end)

  end)



  describe("scroll_up()", function()

    it("scrolls up by scroll_step", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"}, scroll_step = 2 }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)

      panel:set_position(3) -- max position for 5 lines with height 3
      panel:scroll_up()

      assert.are.equal(1, panel.position)
    end)


    it("does not scroll below 1", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, scroll_step = 5 }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)

      panel:set_position(2) -- max position for 3 lines with height 2
      panel:scroll_up()

      assert.are.equal(1, panel.position)
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called = false
      panel.render = function() render_called = true end

      panel:scroll_up() -- Already at 1
      assert.is_false(render_called)
    end)

  end)



  describe("scroll_down()", function()

    it("scrolls down by scroll_step", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"}, scroll_step = 2 }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)

      panel:set_position(1)
      panel:scroll_down()

      assert.are.equal(3, panel.position) -- max position for 5 lines with height 3
    end)


    it("does not scroll beyond last line", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, scroll_step = 5 }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)

      panel:set_position(2) -- max position for 3 lines with height 2
      panel:scroll_down()

      assert.are.equal(2, panel.position) -- already at max position
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called
      panel.render = function() render_called = true end

      panel:set_position(2) -- At max position for 3 lines with height 2
      render_called = false -- Reset after set_position call
      panel:scroll_down()
      assert.is_false(render_called)
    end)

  end)



  describe("page_up()", function()

    it("scrolls up by page size", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)
      panel:set_position(5) -- Start at position 5

      panel:page_up()
      assert.are.equal(2, panel:get_position()) -- 5 - 3 = 2
    end)


    it("does not scroll below 1", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)
      panel:set_position(2) -- Start at position 2

      panel:page_up()
      assert.are.equal(1, panel:get_position()) -- Clamped to 1
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called
      panel.render = function() render_called = true end

      panel:set_position(1) -- At position 1
      render_called = false -- Reset after set_position call
      panel:page_up()
      assert.is_false(render_called)
    end)

  end)



  describe("page_down()", function()

    it("scrolls down by page size", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)
      panel:set_position(2) -- Start at position 2

      panel:page_down()
      assert.are.equal(5, panel:get_position()) -- 2 + 3 = 5
    end)


    it("does not scroll beyond last line", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width (3 lines visible)
      panel:set_position(3) -- Start at position 3 (max for 5 lines with height 3)

      panel:page_down()
      assert.are.equal(3, panel:get_position()) -- Clamped to max position
    end)


    it("does not render if position unchanged", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called
      panel.render = function() render_called = true end

      panel:set_position(2) -- At max position for 3 lines with height 2
      render_called = false -- Reset after set_position call
      panel:page_down()
      assert.is_false(render_called)
    end)

  end)



  describe("get_position()", function()

    it("returns current position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)

      panel:set_position(2) -- max position for 3 lines with height 2

      assert.are.equal(2, panel:get_position())
    end)

  end)



  describe("get_line_count()", function()

    it("returns number of lines", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d"} }
      panel:calculate_layout(1, 1, 10, 20)

      assert.are.equal(4, panel:get_line_count())
    end)


    it("returns 0 for empty lines", function()
      local panel = TextPanel { lines = {} }
      panel:calculate_layout(1, 1, 10, 20)

      assert.are.equal(0, panel:get_line_count())
    end)

  end)


  describe("get_source_line_index()", function()

    it("returns correct source line index for simple truncation", function()
      local panel = TextPanel { lines = {"line1", "line2", "line3"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      -- With truncation formatter, each source line maps to one formatted line
      assert.are.equal(1, panel:get_source_line_index(1))
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(3, panel:get_source_line_index(3))
    end)


    it("returns nil for out of bounds display line index", function()
      local panel = TextPanel { lines = {"line1", "line2"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      assert.is_nil(panel:get_source_line_index(0))
      assert.is_nil(panel:get_source_line_index(3))
      assert.is_nil(panel:get_source_line_index(-1))
    end)


    it("returns nil for empty panel", function()
      local panel = TextPanel { lines = {} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      assert.is_nil(panel:get_source_line_index(1))
    end)


    it("handles wordwrap formatter correctly", function()
      local panel = TextPanel {
        lines = {"short", "very long line that will wrap", "another short"},
        line_formatter = TextPanel.format_line_wordwrap
      }
      panel:calculate_layout(1, 1, 15, 15) -- width = 15
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      -- First line: "short" -> 1 formatted line
      assert.are.equal(1, panel:get_source_line_index(1))

      -- Second line: "very long line that will wrap" -> multiple formatted lines
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(2, panel:get_source_line_index(3))

      -- Third line: "another short" -> 1 formatted line
      assert.are.equal(3, panel:get_source_line_index(4))

      -- ensure it was the last one
      assert.is_nil(panel:get_source_line_index(5))
    end)


    it("maintains correct mapping after add_line with max_lines", function()
      local panel = TextPanel {
        lines = {"a", "b", "c"},
        line_formatter = TextPanel.format_line_wordwrap,
        max_lines = 3
      }
      panel:calculate_layout(1, 1, 15, 15)
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      -- Initial mapping
      assert.are.equal(1, panel:get_source_line_index(1))
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(3, panel:get_source_line_index(3))
      assert.is_nil(panel:get_source_line_index(4))

      -- Add 2 formatted lines - should remove "a" and shift references
      panel:add_line("more than 15 so wraps")
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      -- New mapping: ["b", "c", "more than 15 so wraps"] -> source lines [1, 2, 3]
      -- so we have 4 formatted lines now, but only 3 source lines
      assert.are.equal(1, panel:get_source_line_index(1))
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(3, panel:get_source_line_index(3))
      assert.are.equal(3, panel:get_source_line_index(4))
      assert.is_nil(panel:get_source_line_index(5))

      -- rotate the wrapped line out and validate the mapping
      panel:add_line("d")
      panel:add_line("e")
      panel:add_line("f")
      panel:get_line_count()

      assert.are.equal(1, panel:get_source_line_index(1))
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(3, panel:get_source_line_index(3))
      assert.is_nil(panel:get_source_line_index(4))
    end)


    it("handles set_lines correctly", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count() -- Ensure formatted_lines and line_refs are built

      -- Change to new lines
      panel:set_lines({"x", "y", "z", "w"})
      panel:get_line_count() -- Rebuild formatted_lines and line_refs after set_lines

      -- New mapping should be 1:1 for truncation
      assert.are.equal(1, panel:get_source_line_index(1))
      assert.are.equal(2, panel:get_source_line_index(2))
      assert.are.equal(3, panel:get_source_line_index(3))
      assert.are.equal(4, panel:get_source_line_index(4))
      assert.is_nil(panel:get_source_line_index(5))
    end)

  end)


  describe("highlight functionality", function()

    it("initializes with no highlight by default", function()
      local panel = TextPanel { lines = {"line1", "line2", "line3"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      assert.is_nil(panel.highlight)
      assert.are.same({ reverse = true }, panel.highlight_attr)
    end)


    it("can set highlight via constructor", function()
      local panel = TextPanel {
        lines = {"line1", "line2", "line3"},
        highlight = 2,
        highlight_attr = { fg = "red", bg = "yellow" }
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      assert.are.equal(2, panel.highlight)
      assert.are.same({ fg = "red", bg = "yellow" }, panel.highlight_attr)
    end)


    it("set_highlight sets highlight correctly", function()
      local panel = TextPanel { lines = {"line1", "line2", "line3"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      panel:set_highlight(2)
      assert.are.equal(2, panel.highlight)
    end)


    it("set_highlight removes highlight when set to nil", function()
      local panel = TextPanel {
        lines = {"line1", "line2", "line3"},
        highlight = 2
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      panel:set_highlight(nil)
      assert.is_nil(panel.highlight)
    end)


    it("set_highlight removes highlight when source_line_idx is out of bounds", function()
      local panel = TextPanel { lines = {"line1", "line2", "line3"} }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      -- Test negative index
      panel:set_highlight(-1)
      assert.is_nil(panel.highlight)

      -- Test zero index
      panel:set_highlight(0)
      assert.is_nil(panel.highlight)

      -- Test index beyond bounds
      panel:set_highlight(4)
      assert.is_nil(panel.highlight)
    end)


    it("set_highlight triggers auto_render when enabled", function()
      local panel = TextPanel {
        lines = {"line1", "line2", "line3"},
        auto_render = true
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      -- Mock render method to track calls
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_highlight(2)
      assert.is_true(render_called)
    end)


    it("set_highlight does not trigger auto_render when disabled", function()
      local panel = TextPanel {
        lines = {"line1", "line2", "line3"},
        auto_render = false
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      -- Mock render method to track calls
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_highlight(2)
      assert.is_false(render_called)
    end)


    it("highlight works with wordwrap formatter", function()
      local panel = TextPanel {
        lines = {"short", "very long line that will wrap to multiple lines", "another short"},
        line_formatter = TextPanel.format_line_wordwrap,
        highlight = 2
      }
      panel:calculate_layout(1, 1, 15, 15)
      panel:get_line_count()

      -- The second source line should be highlighted
      assert.are.equal(2, panel.highlight)

      -- Check that all formatted lines from source line 2 are marked for highlighting
      local highlighted_lines = 0
      for i = 1, #panel.formatted_lines do
        local source_line_idx = panel:get_source_line_index(i)
        if source_line_idx == 2 then
          highlighted_lines = highlighted_lines + 1
        end
      end
      assert.is_true(highlighted_lines > 1) -- Should have multiple lines from wrapping
    end)


    it("highlight persists after add_line with max_lines", function()
      local panel = TextPanel {
        lines = {"a", "b", "c"},
        max_lines = 3,
        highlight = 2
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      -- Add line "d" - should remove "a" and shift references
      panel:add_line("d")

      -- Highlight should now point to source line 1 (which was originally "b")
      assert.are.equal(1, panel.highlight)

      -- Verify the mapping is correct
      assert.are.equal(1, panel:get_source_line_index(1)) -- Display line 1 -> Source line 1
    end)


    it("highlight is pinned to 1 when highlighted line is removed by max_lines", function()
      local panel = TextPanel {
        lines = {"a", "b"},
        max_lines = 2,
        highlight = 1
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()

      -- Add line "c" - should remove "a" (the highlighted line)
      panel:add_line("c")

      -- Highlight should be pinned to 1
      assert.are.equal(1, panel.highlight)
    end)


    it("highlight resets with set_lines", function()
      local panel = TextPanel {
        lines = {"a", "b", "c"},
        highlight = 2
      }
      panel:calculate_layout(1, 1, 10, 20)
      panel:get_line_count()
      assert.are.equal(2, panel.highlight)

      -- Change to new lines
      panel:set_lines({"x", "y", "z", "w"})
      panel:get_line_count()

      -- Highlight should be cleared
      assert.is_nil(panel.highlight)
    end)


    it("set_highlight with jump=true adjusts viewport when highlighted line is above viewport", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5
      panel:get_line_count()

      -- Set position to show lines 6-10
      panel:set_position(6)
      assert.are.equal(6, panel.position)

      -- Highlight line 2 (above viewport) with jump=true
      panel:set_highlight(2, true)

      -- Viewport should jump to show line 2 at the top
      assert.are.equal(2, panel.position)
      assert.are.equal(2, panel.highlight)
    end)


    it("set_highlight with jump=true adjusts viewport when highlighted line is below viewport", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5
      panel:get_line_count()

      -- Set position to show lines 1-5
      panel:set_position(1)
      assert.are.equal(1, panel.position)

      -- Highlight line 8 (below viewport) with jump=true
      panel:set_highlight(8, true)

      -- Viewport should jump to show line 8 at the bottom
      assert.are.equal(4, panel.position) -- 8 - 5 + 1 = 4
      assert.are.equal(8, panel.highlight)
    end)


    it("set_highlight with jump=true does not adjust viewport when highlighted line is already visible", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5
      panel:get_line_count()

      -- Set position to show lines 3-7
      panel:set_position(3)
      assert.are.equal(3, panel.position)

      -- Highlight line 5 (already visible) with jump=true
      panel:set_highlight(5, true)

      -- Viewport should not change
      assert.are.equal(3, panel.position)
      assert.are.equal(5, panel.highlight)
    end)


    it("set_highlight with jump=true handles wrapped lines below viewport correctly", function()
      local panel = TextPanel {
        lines = {"a", "b", "c", "d", "e", "this wraps to 3 lines at width 15", "f", "g", "h", "i", "j"},
        line_formatter = TextPanel.format_line_wordwrap
      }
      panel:calculate_layout(1, 1, 5, 15) -- height = 5, width = 15
      panel:get_line_count()

      -- Set position to show earlier lines
      panel:set_position(1)

      -- Highlight line 6 (which wraps to multiple formatted lines) with jump=true
      panel:set_highlight(6, true)

      -- Viewport should adjust to show all wrapped lines of the highlighted source line
      assert.are.equal(6, panel.highlight)
      -- The position should be adjusted to show all formatted lines of source line 6
      assert.is.equal(4, panel.position) -- show "d", "e", and 3 wrapped lines, total 5 lines
    end)


    it("set_highlight with jump=true handles wrapped lines above viewport correctly", function()
      local panel = TextPanel {
        lines = {"a", "b", "c", "d", "e", "this wraps to 3 lines at width 15", "f", "g", "h", "i", "j"},
        line_formatter = TextPanel.format_line_wordwrap
      }
      panel:calculate_layout(1, 1, 5, 15) -- height = 5, width = 15
      panel:get_line_count()

      -- Set position to show later lines; f - j
      panel:set_position(9)

      -- Highlight line 6 (which wraps to multiple formatted lines) with jump=true
      panel:set_highlight(6, true)

      -- Viewport should adjust to show all wrapped lines of the highlighted source line
      assert.are.equal(6, panel.highlight)
      -- The position should be adjusted to show all formatted lines of source line 6
      assert.is.equal(6, panel.position) -- show 3 wrapped lines, "f", and "g"; total 5 lines
    end)


    it("set_highlight with jump=false does not adjust viewport", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5
      panel:get_line_count()

      -- Set position to show lines 6-10
      panel:set_position(6)
      assert.are.equal(6, panel.position)

      -- Highlight line 2 (above viewport) with jump=false
      panel:set_highlight(2, false)

      -- Viewport should not change
      assert.are.equal(6, panel.position)
      assert.are.equal(2, panel.highlight)
    end)


    it("set_highlight with jump parameter defaults to false", function()
      local panel = TextPanel { lines = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5
      panel:get_line_count()

      -- Set position to show lines 6-10
      panel:set_position(6)
      assert.are.equal(6, panel.position)

      -- Highlight line 2 (above viewport) without jump parameter
      panel:set_highlight(2)

      -- Viewport should not change (jump defaults to false)
      assert.are.equal(6, panel.position)
      assert.are.equal(2, panel.highlight)
    end)


    it("set_highlight with jump=true handles edge cases", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 5, 20) -- height = 5 (larger than content)
      panel:get_line_count()

      -- Highlight line 1 with jump=true
      panel:set_highlight(1, true)

      -- Should work without errors
      assert.are.equal(1, panel.position)
      assert.are.equal(1, panel.highlight)
    end)

  end)



  describe("set_lines()", function()

    it("sets new lines and resets position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width

      panel:set_position(3)
      panel:set_lines({"x", "y"})

      assert.are.same({"x", "y"}, panel.lines)
      assert.are.equal(1, panel.position)
    end)


    it("handles nil input", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width

      panel:set_lines(nil)

      assert.are.same({}, panel.lines)
      assert.are.equal(1, panel.position)
    end)

  end)


  describe("add_line()", function()

    it("adds line to end", function()
      local panel = TextPanel { lines = {"a", "b"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width

      panel:add_line("c")

      assert.are.same({"a", "b", "c"}, panel.lines)
    end)


    it("handles nil input", function()
      local panel = TextPanel { lines = {"a", "b"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width

      panel:add_line(nil)

      assert.are.same({"a", "b", ""}, panel.lines)
    end)

  end)


  describe("clear_lines()", function()

    it("clears all lines and resets position", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width

      panel:set_position(3)
      panel:clear_lines()

      assert.are.same({}, panel.lines)
      assert.are.equal(1, panel.position)
    end)

  end)


  describe("auto_render", function()

    it("defaults to false", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }

      assert.is_false(panel.auto_render)
    end)


    it("can be set to true", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = true }

      assert.is_true(panel.auto_render)
    end)


    it("can be set to false explicitly", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = false }

      assert.is_false(panel.auto_render)
    end)


    it("renders automatically when auto_render is true", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = true }
      panel:calculate_layout(1, 1, 2, 10) -- row, col, height, width (2 lines visible)
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_position(2) -- max position for 3 lines with height 2
      assert.is_true(render_called)
    end)


    it("does not render automatically when auto_render is false", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = false }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_position(2)
      assert.is_false(render_called)
    end)


    it("renders automatically on set_lines when auto_render is true", function()
      local panel = TextPanel { lines = {"a", "b"}, auto_render = true }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width
      local render_called = false
      panel.render = function() render_called = true end

      panel:set_lines({"x", "y", "z"})
      assert.is_true(render_called)
    end)


    it("renders automatically on add_line when auto_render is true", function()
      local panel = TextPanel { lines = {"a", "b"}, auto_render = true }
      panel:calculate_layout(1, 1, 5, 10) -- row, col, height, width (height 5 to ensure new line is visible)
      panel:set_position(1) -- Ensure we're at the top to see the new line
      local render_called = false
      panel.render = function() render_called = true end

      panel:add_line("c")
      assert.is_true(render_called)
    end)


    it("renders automatically on clear_lines when auto_render is true", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, auto_render = true }
      panel:calculate_layout(1, 1, 3, 10) -- row, col, height, width
      local render_called = false
      panel.render = function() render_called = true end

      panel:clear_lines()
      assert.is_true(render_called)
    end)

  end)


  describe("line formatter system", function()

    it("uses format_line_truncate by default", function()
      local panel = TextPanel {}
      assert.are.equal(panel.format_line_truncate, panel.line_formatter)
    end)


    it("can be set via constructor", function()
      local panel = TextPanel {}
      local custom_formatter = panel.format_line_wrap
      local panel2 = TextPanel { line_formatter = custom_formatter }
      assert.are.equal(custom_formatter, panel2.line_formatter)
    end)


    it("set_line_formatter changes formatter and resets formatted_lines", function()
      local panel = TextPanel { lines = {"test"}, auto_render = false }
      panel:calculate_layout(1, 1, 10, 20)

      -- Trigger formatted_lines build by calling _draw_text
      panel:_draw_text()
      assert.is_not_nil(panel.formatted_lines)

      -- change formatter
      panel:set_line_formatter(panel.format_line_wrap)

      -- formatter should be changed and formatted_lines reset
      assert.are.equal(panel.format_line_wrap, panel.line_formatter)
      assert.is_nil(panel.formatted_lines)
    end)


    it("set_line_formatter triggers auto_render when enabled", function()
      local panel = TextPanel { lines = {"test"}, auto_render = true }
      panel:calculate_layout(1, 1, 10, 20)

      -- Mock render to track calls
      local render_calls = 0
      panel.render = function() render_calls = render_calls + 1 end

      panel:set_line_formatter(panel.format_line_wrap)

      assert.are.equal(1, render_calls)
    end)


    it("set_line_formatter does not trigger auto_render when disabled", function()
      local panel = TextPanel { lines = {"test"}, auto_render = false }
      panel:calculate_layout(1, 1, 10, 20)

      -- Mock render to track calls
      local render_calls = 0
      panel.render = function() render_calls = render_calls + 1 end

      panel:set_line_formatter(panel.format_line_wrap)

      assert.are.equal(0, render_calls)
    end)


    it("format_line_wrap placeholder works", function()
      local panel = TextPanel {}
      local result = panel:format_line_wrap("test", 10)

      -- Should fall back to truncate behavior
      assert.are.equal("test      ", result[1])
    end)


    it("format_line_wordwrap placeholder works", function()
      local panel = TextPanel {}
      local result = panel:format_line_wordwrap("test", 10)

      -- Should fall back to truncate behavior
      assert.are.equal("test      ", result[1])
    end)

  end)


  describe("max_lines", function()

    it("has no limit when max_lines is not set", function()
      local panel = TextPanel { lines = {"a", "b", "c"} }
      panel:calculate_layout(1, 1, 3, 10)

      panel:add_line("d")
      panel:add_line("e")
      panel:add_line("f")

      assert.are.equal(6, #panel.lines)
      assert.are.equal(6, panel:get_line_count())
    end)


    it("enforces max_lines limit by removing old lines", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, max_lines = 3 }
      panel:calculate_layout(1, 1, 3, 10)

      panel:add_line("d") -- Should remove "a", keeping ["b", "c", "d"]

      assert.are.equal(3, #panel.lines)
      assert.are.equal("b", panel.lines[1])
      assert.are.equal("c", panel.lines[2])
      assert.are.equal("d", panel.lines[3])
    end)


    it("adjusts position when lines are removed", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, max_lines = 3 }
      panel:calculate_layout(1, 1, 3, 10)
      panel:set_position(2) -- Position at line 2

      panel:add_line("d") -- Should remove "a", position becomes 1

      assert.are.equal(1, panel:get_position())
    end)


    it("clamps position to 1 when it would go below", function()
      local panel = TextPanel { lines = {"a", "b" }, max_lines = 2 }
      panel:calculate_layout(1, 1, 3, 10)
      panel:set_position(1) -- Position at line 1

      panel:add_line("c") -- Should remove "a", position stays at 1

      assert.are.equal(1, panel:get_position())
      assert.are.equal(2, #panel.lines)
    end)


    it("handles multiple lines exceeding max_lines", function()
      local panel = TextPanel { lines = {"a", "b"}, max_lines = 3 }
      panel:calculate_layout(1, 1, 3, 10)

      panel:add_line("c")
      panel:add_line("d")
      panel:add_line("e") -- Should remove "a" and "b", keeping ["c", "d", "e"]

      assert.are.equal(3, #panel.lines)
      assert.are.equal("c", panel.lines[1])
      assert.are.equal("d", panel.lines[2])
      assert.are.equal("e", panel.lines[3])
    end)


    it("updates formatted_lines when lines are removed", function()
      local panel = TextPanel { lines = {"a", "b", "c"}, max_lines = 3 }
      panel:calculate_layout(1, 1, 3, 10)

      -- Ensure formatted_lines is built
      panel:get_line_count()
      assert.is_not_nil(panel.formatted_lines)

      panel:add_line("d") -- Should remove "a" and rebuild formatted_lines

      assert.are.same({"b         ", "c         ", "d         "}, panel.formatted_lines)
    end)

  end)

end)
