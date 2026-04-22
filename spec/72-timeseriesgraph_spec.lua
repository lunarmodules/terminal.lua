local helpers = require "spec.helpers"



describe("terminal.ui.timeseriesgraph", function()

  local TimeSeriesGraph

  setup(function()
    helpers.load()
    TimeSeriesGraph = require "terminal.ui.timeseriesgraph"
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
      assert.are.equal(80, g:get_max())  -- nice_ceil(73) = 80
    end)

    it("expands dynamic min to the next nice boundary", function()
      local g = TimeSeriesGraph()
      g:push(-37)
      assert.are.equal(-40, g:get_min())  -- nice_floor(-37) = -40
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
      assert.are.equal(-40, g:get_min())
    end)

    it("does not change when a push is within the current bounds", function()
      local g = TimeSeriesGraph()
      g:push(-40)
      g:push(-20)
      assert.are.equal(-40, g:get_min())
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
      assert.are.equal(80, g:get_max())
    end)

    it("does not change when a push is within the current bounds", function()
      local g = TimeSeriesGraph()
      g:push(73)   -- snaps max to 80
      g:push(50)   -- within bounds, max stays 80
      assert.are.equal(80, g:get_max())
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

    pending("does nothing when no samples have been pushed", function()
      -- TODO: implement
    end)

    pending("does nothing when min equals max", function()
      -- TODO: implement
    end)

    pending("draws a data line through a viewport", function()
      -- TODO: implement
    end)

    pending("draws the Y-axis at x=0", function()
      -- TODO: implement
    end)

    pending("draws the X-axis at the bottom when range is all positive", function()
      -- TODO: implement
    end)

    pending("draws the X-axis at the top when range is all negative", function()
      -- TODO: implement
    end)

    pending("draws the X-axis at the midpoint when range straddles zero", function()
      -- TODO: implement
    end)

    pending("draws auto-generated tick marks at physical x=1", function()
      -- TODO: implement
    end)

    pending("draws explicit tick marks at physical x=1", function()
      -- TODO: implement
    end)

    pending("skips tick marks that fall outside the canvas pixel height", function()
      -- TODO: implement
    end)

  end)



  describe("render()", function()

    pending("returns a Sequence", function()
      -- TODO: implement
    end)

    pending("renders without labels when opts.fmt is omitted", function()
      -- TODO: implement
    end)

    pending("renders the max label at the top and min label at the bottom", function()
      -- TODO: implement
    end)

    pending("right-aligns labels of different widths", function()
      -- TODO: implement
    end)

    pending("narrows the graph canvas to fit the label column", function()
      -- TODO: implement
    end)

    pending("drops labels when there is not enough space", function()
      -- TODO: implement
    end)

    pending("applies graph_attr to the graph area", function()
      -- TODO: implement
    end)

    pending("applies label_attr to the label area", function()
      -- TODO: implement
    end)

    pending("returns to the starting column after rendering", function()
      -- TODO: implement
    end)

  end)

end)
