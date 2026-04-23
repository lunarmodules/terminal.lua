local helpers = require "spec.helpers"

local lines = require("pl.stringx").splitlines



describe("terminal.ui.timeseriesgraph", function()

  local TimeSeriesGraph
  local Canvas
  local Sequence
  local strip_ansi

  setup(function()
    helpers.load()
    TimeSeriesGraph = require "terminal.ui.timeseriesgraph"
    Canvas = require "terminal.ui.canvas"
    Sequence = require "terminal.sequence"
    strip_ansi = require("terminal.utils").strip_ansi
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a graph with default options", function()
      local g = TimeSeriesGraph()
      assert.is_not_nil(g)
      assert.are.equal(math.huge,  g:get_min())
      assert.are.equal(-math.huge, g:get_max())
    end)


    it("creates a graph with explicit min and max", function()
      local g = TimeSeriesGraph({ min = -50, max = 50 })
      assert.are.equal(-50, g:get_min())
      assert.are.equal( 50, g:get_max())
    end)


    it("creates a graph with explicit ticks", function()
      local ticks = { 25, 50, 75 }
      local g = TimeSeriesGraph({ min = 0, max = 100, ticks = ticks })
      assert.is_not_nil(g)
    end)


    it("creates a graph with explicit history size", function()
      local g = TimeSeriesGraph({ history = 50, min = 0, max = 1 })
      for i = 1, 60 do g:push(i % 2) end
      assert.are.equal(50, #g._samples)
    end)


    it("errors when history is not a positive integer", function()
      assert.has_error(function() TimeSeriesGraph({ history = 0 }) end)
      assert.has_error(function() TimeSeriesGraph({ history = -1 }) end)
      assert.has_error(function() TimeSeriesGraph({ history = 1.5 }) end)
      assert.has_error(function() TimeSeriesGraph({ history = "bad" }) end)
    end)


    it("errors when opts is not a table", function()
      assert.has_error(function() TimeSeriesGraph("bad") end)
      assert.has_error(function() TimeSeriesGraph(42) end)
    end)


    it("errors when max is not greater than min", function()
      assert.has_error(function() TimeSeriesGraph({ min = 10, max = 10 }) end)
      assert.has_error(function() TimeSeriesGraph({ min = 10, max =  5 }) end)
    end)

  end)



  describe("push()", function()

    it("adds a sample to the history", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(10)
      g:push(20)
      assert.are.equal(2, #g._samples)
      assert.are.equal(10, g._samples[1])
      assert.are.equal(20, g._samples[2])
    end)


    it("drops the oldest sample when history is full", function()
      local g = TimeSeriesGraph({ history = 3, min = 0, max = 100 })
      g:push(1)
      g:push(2)
      g:push(3)
      g:push(4)
      assert.are.equal(3, #g._samples)
      assert.are.equal(2, g._samples[1])
      assert.are.equal(4, g._samples[3])
    end)


    it("expands dynamic max to the next nice boundary", function()
      local g = TimeSeriesGraph()
      g:push(73)
      assert.are.equal(100, g:get_max())  -- nice_ceil(73) = 100
    end)


    it("expands dynamic min to the next nice boundary", function()
      local g = TimeSeriesGraph()
      g:push(-37)
      assert.are.equal(-50, g:get_min())  -- nice_floor(-37) = -50
    end)


    it("does not expand a fixed min below a new value", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(-50)
      assert.are.equal(0, g:get_min())
    end)


    it("does not expand a fixed max above a new value", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(150)
      assert.are.equal(100, g:get_max())
    end)


    it("errors when value is not a number", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      assert.has_error(function() g:push("bad") end)
      assert.has_error(function() g:push(nil) end)
      assert.has_error(function() g:push(true) end)
    end)


    it("handles the edge case where value lands exactly on a nice boundary", function()
      -- nice_floor(10) == nice_ceil(10) == 10, so min would equal max
      -- the implementation forces a 1-unit gap in that case
      local g = TimeSeriesGraph()
      g:push(10)
      assert.is_true(g:get_max() > g:get_min())
    end)

  end)



  describe("get_min()", function()

    it("returns the fixed min when set explicitly", function()
      local g = TimeSeriesGraph({ min = -10, max = 10 })
      assert.are.equal(-10, g:get_min())
    end)


    it("returns huge before any push for dynamic range", function()
      local g = TimeSeriesGraph()
      assert.are.equal(math.huge, g:get_min())
    end)


    it("returns the snapped min after a push expands the lower bound", function()
      local g = TimeSeriesGraph()
      g:push(-37)
      assert.are.equal(-50, g:get_min())
    end)


    it("does not change when a push is within the current bounds", function()
      local g = TimeSeriesGraph()
      g:push(-20)   -- nice_floor(-20) = -20
      g:push(-10)   -- within bounds, min stays -20
      assert.are.equal(-20, g:get_min())
    end)

  end)



  describe("get_max()", function()

    it("returns the fixed max when set explicitly", function()
      local g = TimeSeriesGraph({ min = -10, max = 10 })
      assert.are.equal(10, g:get_max())
    end)


    it("returns -huge before any push for dynamic range", function()
      local g = TimeSeriesGraph()
      assert.are.equal(-math.huge, g:get_max())
    end)


    it("returns the snapped max after a push expands the upper bound", function()
      local g = TimeSeriesGraph()
      g:push(73)
      assert.are.equal(100, g:get_max())
    end)


    it("does not change when a push is within the current bounds", function()
      local g = TimeSeriesGraph()
      g:push(47)   -- nice_ceil(47) = 50
      g:push(20)   -- within bounds, max stays 50
      assert.are.equal(50, g:get_max())
    end)

  end)



  describe("clear()", function()

    it("empties the sample history", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(10)
      g:push(20)
      g:clear()
      assert.are.equal(0, #g._samples)
    end)


    it("resets dynamic min/max to sentinel values", function()
      local g = TimeSeriesGraph()
      g:push(73)
      g:push(-37)
      g:clear()
      assert.are.equal(math.huge,  g:get_min())
      assert.are.equal(-math.huge, g:get_max())
    end)


    it("does not reset fixed min/max", function()
      local g = TimeSeriesGraph({ min = -50, max = 50 })
      g:push(10)
      g:clear()
      assert.are.equal(-50, g:get_min())
      assert.are.equal( 50, g:get_max())
    end)

  end)



  describe("draw()", function()

    it("does nothing when no samples have been pushed", function()
      local g = TimeSeriesGraph()
      local c = Canvas({ width = 5, height = 5 })
      local before = c:render({ print = true })
      g:draw(c)
      assert.are.equal(before, c:render({ print = true }))
    end)


    it("draws a data line through a viewport", function()
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 10 })
      local c = Canvas({ width = 5, height = 5 })
      g:push(100)
      g:push(100)
      g:draw(c)
      local before = c:render({ print = true })
      g:push(0)
      g:push(0)
      c:clear()
      g:draw(c)
      assert.are_not.equal(before, c:render({ print = true }))
    end)


    it("draws the Y-axis at x=0", function()
      -- 1 row × 2 cols → 4px wide × 4px tall. history=1 keeps sample count
      -- at 1 so no polygon is drawn, leaving only the axes.
      -- ticks={} suppresses tick marks.
      -- Expected render (print mode, no cursor sequences):
      --   ⣇  left cell: left column fully lit (Y-axis x=0, all 4 rows)
      --               + bottom-right pixel (X-axis x=1, y=3)
      --   ⣀  right cell: both bottom pixels (X-axis x=2..3, y=3)
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 1, ticks = {} })
      local c = Canvas({ width = 2, height = 1 })
      g:push(50)
      g:draw(c)
      assert.are.equal("⣇⣀", c:render({ print = true }))
    end)


    it("draws the X-axis at the bottom when range is all positive", function()
      -- X-axis at value=0 clamped to bottom (y=3). 1 sample → no polygon.
      -- ⣇  Y-axis (left col) + X-axis bottom-right pixel (x=1, y=3)
      -- ⣀  X-axis bottom two pixels (x=2..3, y=3)
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 1, ticks = {} })
      local c = Canvas({ width = 2, height = 1 })
      g:push(50)
      g:draw(c)
      assert.are.equal("⣇⣀", c:render({ print = true }))
    end)


    it("draws the X-axis at the top when range is all negative", function()
      -- X-axis at value=0 clamped to top (y=0). 1 sample → no polygon.
      -- ⡏  Y-axis (left col) + X-axis top-right pixel (x=1, y=0)
      -- ⠉  X-axis top two pixels (x=2..3, y=0)
      local g = TimeSeriesGraph({ min = -100, max = -10, history = 1, ticks = {} })
      local c = Canvas({ width = 2, height = 1 })
      g:push(-50)
      g:draw(c)
      assert.are.equal("⡏⠉", c:render({ print = true }))
    end)


    it("draws the X-axis at the midpoint when range straddles zero", function()
      -- X-axis at value=0 maps to y=1 (second pixel). 1 sample → no polygon.
      -- ⡗  Y-axis (left col) + X-axis mid-right pixel (x=1, y=1)
      -- ⠒  X-axis mid two pixels (x=2..3, y=1)
      local g = TimeSeriesGraph({ min = -50, max = 50, history = 1, ticks = {} })
      local c = Canvas({ width = 2, height = 1 })
      g:push(25)
      g:draw(c)
      assert.are.equal("⡗⠒", c:render({ print = true }))
    end)


    it("draws auto-generated tick marks at physical x=1", function()
      -- 2 cols × 4 rows → 4px × 16px. min=0, max=100, no polygon (1 sample).
      -- auto_ticks gives 0, 50, 100 → tick pixels at (1,0), (1,7), (1,15).
      -- ⡏  row 1: Y-axis + tick at (x=1, y=0)
      -- ⣇  row 2: Y-axis + tick at (x=1, y=7)
      -- ⡇  row 3: Y-axis only
      -- ⣇⣀ row 4: Y-axis + X-axis + tick at (x=1, y=15)
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 1 })
      local c = Canvas({ width = 2, height = 4 })
      g:push(50)
      g:draw(c)
      assert.are.same(
        { "⡏⠀",
          "⣇⠀",
          "⡇⠀",
          "⣇⣀" },
        lines(c:render({ print = true }))
      )
    end)


    it("draws explicit tick marks at physical x=1", function()
      -- Explicit ticks {25, 75} → tick pixels at (1,3) and (1,11).
      -- ⣇  row 1: Y-axis + tick at (x=1, y=3)
      -- ⡇  row 2: Y-axis only
      -- ⣇  row 3: Y-axis + tick at (x=1, y=11)
      -- ⣇⣀ row 4: Y-axis + X-axis
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 1, ticks = { 25, 75 } })
      local c = Canvas({ width = 2, height = 4 })
      g:push(50)
      g:draw(c)
      assert.are.same(
        { "⣇⠀",
          "⡇⠀",
          "⣇⠀",
          "⣇⣀" },
        lines(c:render({ print = true }))
      )
    end)


    it("skips tick marks that fall outside the canvas pixel height", function()
      -- Ticks {-10, 50, 150}: -10 and 150 map outside 0..15 and are skipped;
      -- only 50 is drawn at (1,7).
      -- ⡇  row 1: Y-axis only  (no tick from -10 or 150)
      -- ⣇  row 2: Y-axis + tick at (x=1, y=7)  (value 50)
      -- ⡇  row 3: Y-axis only
      -- ⣇⣀ row 4: Y-axis + X-axis
      local g = TimeSeriesGraph({ min = 0, max = 100, history = 1, ticks = { -10, 50, 150 } })
      local c = Canvas({ width = 2, height = 4 })
      g:push(50)
      g:draw(c)
      assert.are.same(
        { "⡇⠀",
          "⣇⠀",
          "⡇⠀",
          "⣇⣀" },
        lines(c:render({ print = true }))
      )
    end)

  end)



  describe("render()", function()

    -- Converts a render() Sequence into a table of strings, one per row.
    -- The render output is two side-by-side blocks: an optional label column on
    -- the left and the braille graph on the right. Algorithm:
    --   1. Replace cursor-down sequences with newlines.
    --   2. Strip all remaining ANSI codes.
    --   3. Split at the first braille character: everything before is the label
    --      block, everything from that character onward is the graph block.
    --   4. Split each block into lines and zip them together.
    local function render_rows(result)
      local s = tostring(result)
      s = s:gsub("\027%[%d+B", "\n")
      s = require("terminal.utils").strip_ansi(s)
      local braille_pos = s:find("\226[\160-\163][\128-\191]")
      if not braille_pos then return {} end
      local label_lines = lines(s:sub(1, braille_pos - 1))
      local graph_lines = lines(s:sub(braille_pos))
      local rows = {}
      for i, graph_line in ipairs(graph_lines) do
        rows[i] = (label_lines[i] or "") .. graph_line
      end
      return rows
    end


    it("returns a Sequence", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      local result = g:render({ cols = 10, rows = 3 })
      assert.are.equal(Sequence, getmetatable(result))
    end)


    it("renders without labels when opts.fmt is omitted", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      assert.are.same(
        { "⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀",
          "⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀",
          "⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 3, fmt = nil }))
      )
    end)


    it("renders the max label at the top and min label at the bottom", function()
      local g = TimeSeriesGraph({ min = 25, max = 75 })
      g:push(50)
      assert.are.same(
        { "75⡇⠀⠀⠀⠀⠀⠀⠀",
          "  ⡗⠀⠀⠀⠀⠀⠀⠀",
          "25⣇⣀⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 3, fmt = "%d" }))
      )
    end)


    it("right-aligns labels of different widths", function()
      -- min=0 → label "0" (1 char), max=100 → label "100" (3 chars)
      -- label_width=3: max needs no padding, min gets 2 spaces of padding
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      assert.are.same(
        { "100⡏⠀⠀⠀⠀⠀⠀",
          "   ⡇⠀⠀⠀⠀⠀⠀",
          "  0⣇⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 3, fmt = "%d" }))
      )
    end)


    it("narrows the graph canvas to fit the label column", function()
      -- label_width=3 leaves 7 braille columns for the graph;
      -- without labels the full 10 columns are available
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      assert.are.same(
        { "100⡏⠀⠀⠀⠀⠀⠀",
          "   ⡇⠀⠀⠀⠀⠀⠀",
          "  0⣇⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 3, fmt = "%d" }))
      )
      assert.are.same(
        { "⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀",
          "⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀",
          "⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 3, fmt = nil }))
      )
    end)


    it("drops labels when there is not enough space", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      -- rows < 2: labels suppressed, full canvas width used
      assert.are.same(
        { "⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀" },
        render_rows(g:render({ cols = 10, rows = 1, fmt = "%d" }))
      )
      -- cols = 1: labels suppressed, single-column canvas
      assert.are.same(
        { "⡏",
          "⡇",
          "⣇" },
        render_rows(g:render({ cols = 1, rows = 3, fmt = "%d" }))
      )
    end)


    it("applies graph_attr to the graph area", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      local s_plain = tostring(g:render({ cols = 8, rows = 2 }))
      local s_attr  = tostring(g:render({ cols = 8, rows = 2, graph_attr = { fg = "cyan" } }))
      -- attr version differs from plain (extra ANSI codes present)
      assert.are_not.equal(s_plain, s_attr)
      -- stripping ANSI from both yields identical visual content
      assert.are.equal(strip_ansi(s_plain), strip_ansi(s_attr))
    end)


    it("applies label_attr to the label area", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      local s_plain = tostring(g:render({ cols = 8, rows = 2, fmt = "%d" }))
      local s_attr  = tostring(g:render({ cols = 8, rows = 2, fmt = "%d", label_attr = { fg = "red" } }))
      assert.are_not.equal(s_plain, s_attr)
      assert.are.equal(strip_ansi(s_plain), strip_ansi(s_attr))
    end)


    it("returns to the starting column after rendering", function()
      local g = TimeSeriesGraph({ min = 0, max = 100 })
      g:push(50)
      -- with labels (label_width=3): output ends with left_seq(3) to return to start
      local s = tostring(g:render({ cols = 8, rows = 2, fmt = "%d" }))
      assert.is_truthy(s:match("\027%[3D$"))
      -- without labels (label_width=0): left_seq(0) is empty, canvas handles its own return
      local s_no_label = tostring(g:render({ cols = 8, rows = 2 }))
      assert.is_falsy(s_no_label:match("\027%[3D$"))
    end)

  end)

end)
