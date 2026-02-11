local helpers = require "spec.helpers"


describe("terminal.ui.panel.bar", function()

  local Bar

  setup(function()
    helpers.load()
    Bar = require("terminal.ui.panel.bar")
  end)


  teardown(function()
    Bar = nil
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a bar with default values", function()
      local bar = Bar {}

      assert.are.equal(1, bar.margin)
      assert.are.equal(2, bar.padding)
      assert.are.equal("", bar.left)
      assert.are.equal("", bar.center)
      assert.are.equal("", bar.right)
      assert.are.equal(1, bar._min_height)
      assert.are.equal(1, bar._max_height)
    end)


    it("creates a bar with custom values", function()
      local bar = Bar {
        margin = 2,
        padding = 3,
        left = {text = "File"},
        center = {text = "Editor"},
        right = {text = "Help"}
      }

      assert.are.equal(2, bar.margin)
      assert.are.equal(3, bar.padding)
      assert.are.equal("File", bar.left)
      assert.are.equal("Editor", bar.center)
      assert.are.equal("Help", bar.right)
    end)


    it("sets fixed height constraints", function()
      local bar = Bar {}

      assert.are.equal(1, bar._min_height)
      assert.are.equal(1, bar._max_height)
    end)


    it("provides content callback for parent constructor", function()
      local bar = Bar {}

      assert.is_not_nil(bar.content)
      assert.is_function(bar.content)
    end)


    it("sets auto_render property", function()
      local bar = Bar { auto_render = true }

      assert.is_true(bar.auto_render)
    end)


    it("defaults auto_render to false", function()
      local bar = Bar {}

      assert.is_false(bar.auto_render)
    end)

  end)


  describe("_build_bar_line()", function()

    it("builds a simple bar line", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = {text = "L"},
        center = {text = "C"},
        right = {text = "R"}
      }

      local line = bar:_build_bar_line(20)
      local line_str = tostring(line)
      assert.are.equal(" L       C        R ", line_str)
      assert.are.equal(20, #line_str)
    end)


    it("handles empty content", function()
      local bar = Bar {
        margin = 1,
        padding = 2
      }

      local line = bar:_build_bar_line(10)
      local line_str = tostring(line)
      assert.are.equal("          ", line_str)
      assert.are.equal(10, #line_str)
    end)


    it("handles no margin", function()
      local bar = Bar {
        margin = 0,
        padding = 2,
        left = {text = "L"},
        center = {text = "C"},
        right = {text = "R"}
      }

      local line = bar:_build_bar_line(10)
      local line_str = tostring(line)
      assert.are.equal("L   C    R", line_str)
      assert.are.equal(10, #line_str)
    end)


    it("handles no padding", function()
      local bar = Bar {
        margin = 1,
        padding = 0,
        left = {text = "L"},
        center = {text = "C"},
        right = {text = "R"}
      }

      local line = bar:_build_bar_line(10)
      local line_str = tostring(line)
      assert.are.equal(" L  C   R ", line_str)
      assert.are.equal(10, #line_str)
    end)


    it("truncates content when width is insufficient", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = {text = "Very Long Left Content"},
        center = {text = "Center"},
        right = {text = "Right"}
      }

      local line = bar:_build_bar_line(10)
      local line_str = tostring(line)
      -- Should truncate to fit available space (EOL doesn't count toward content length)
      assert.is_true(#line_str >= 6)  -- At least margin + some content
      -- Should start with margin space
      assert.are.equal(" ", line_str:sub(1, 1))
    end)


    it("handles very small width", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = {text = "L"},
        center = {text = "C"},
        right = {text = "R"}
      }

      local line = bar:_build_bar_line(3)
      local line_str = tostring(line)
      -- Should fit margin and minimal content (EOL doesn't count toward content length)
      assert.is_true(#line_str >= 1)  -- At least margin
      -- Should have margin space
      assert.are.equal(" ", line_str:sub(1, 1))
    end)


    it("handles zero width", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = "L",
        center = "C",
        right = "R"
      }

      local line = bar:_build_bar_line(0)
      assert.are.equal("", tostring(line))
    end)


    it("distributes space proportionally when truncating", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = {text = "Very Long Left Content"},
        center = {text = "Very Long Center Content"},
        right = {text = "Very Long Right Content"}
      }

      local line = bar:_build_bar_line(20)
      local line_str = tostring(line)
      -- Should have margin and some content from each section
      assert.are.equal(" ", line_str:sub(1, 1))
      assert.is_true(#line_str >= 10)  -- At least margin + some content
    end)

  end)


  describe("set_left()", function()

    it("sets left content", function()
      local bar = Bar {}
      bar:set_left("New Left")

      assert.are.equal("New Left", bar.left)
    end)


    it("handles nil input", function()
      local bar = Bar { left = {text = "Original"} }
      bar:set_left(nil)

      assert.are.equal("", bar.left)
    end)

  end)


  describe("set_center()", function()

    it("sets center content", function()
      local bar = Bar {}
      bar:set_center("New Center")

      assert.are.equal("New Center", bar.center)
    end)


    it("handles nil input", function()
      local bar = Bar { center = "Original" }
      bar:set_center(nil)

      assert.are.equal("", bar.center)
    end)

  end)


  describe("set_right()", function()

    it("sets right content", function()
      local bar = Bar {}
      bar:set_right("New Right")

      assert.are.equal("New Right", bar.right)
    end)


    it("handles nil input", function()
      local bar = Bar { right = "Original" }
      bar:set_right(nil)

      assert.are.equal("", bar.right)
    end)

  end)


  describe("auto_render", function()

    it("triggers render when auto_render is true and set_left is called", function()
      local bar = Bar { auto_render = true }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_left("New Left")

      assert.is_true(render_called)
    end)


    it("triggers render when auto_render is true and set_center is called", function()
      local bar = Bar { auto_render = true }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_center("New Center")

      assert.is_true(render_called)
    end)


    it("triggers render when auto_render is true and set_right is called", function()
      local bar = Bar { auto_render = true }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_right("New Right")

      assert.is_true(render_called)
    end)


    it("does not trigger render when auto_render is false", function()
      local bar = Bar { auto_render = false }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_left("New Left")
      bar:set_center("New Center")
      bar:set_right("New Right")

      assert.is_false(render_called)
    end)


    it("does not update or render when value has not changed", function()
      local bar = Bar { auto_render = true, left = {text = "Original"} }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_left("Original") -- same value

      assert.are.equal("Original", bar.left)
      assert.is_false(render_called)
    end)


    it("does not update or render when setting nil to empty string", function()
      local bar = Bar { auto_render = true, left = {text = ""} }
      local render_called = false
      bar.render = function() render_called = true end

      bar:set_left(nil) -- nil becomes ""

      assert.are.equal("", bar.left)
      assert.is_false(render_called)
    end)

  end)




  describe("render()", function()

    it("calls _draw_bar with correct parameters", function()
      local bar = Bar {
        margin = 1,
        padding = 2,
        left = {text = "L"},
        center = {text = "C"},
        right = {text = "R"}
      }

      -- Mock _draw_bar to track calls
      local called = false
      local call_args = {}
      bar._draw_bar = function(self)
        called = true
        call_args = { self.inner_row, self.inner_col, self.inner_height, self.inner_width }
      end

      bar.row = 5
      bar.col = 10
      bar.height = 1
      bar.width = 20
      bar.inner_row = 5
      bar.inner_col = 10
      bar.inner_height = 1
      bar.inner_width = 20
      bar:render()

      assert.is_true(called)
      assert.are.same({ 5, 10, 1, 20 }, call_args)
    end)

  end)

end)
