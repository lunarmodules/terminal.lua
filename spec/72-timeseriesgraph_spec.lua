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

    pending("creates a graph with default options", function()
      -- TODO: implement
    end)

    pending("creates a graph with explicit min and max", function()
      -- TODO: implement
    end)

    pending("creates a graph with explicit ticks", function()
      -- TODO: implement
    end)

    pending("creates a graph with explicit history size", function()
      -- TODO: implement
    end)

    pending("errors when opts is not a table", function()
      -- TODO: implement
    end)

    pending("errors when max is not greater than min", function()
      -- TODO: implement
    end)

  end)



  describe("push()", function()

    pending("adds a sample to the history", function()
      -- TODO: implement
    end)

    pending("drops the oldest sample when history is full", function()
      -- TODO: implement
    end)

    pending("expands dynamic max to the next nice boundary", function()
      -- TODO: implement
    end)

    pending("expands dynamic min to the next nice boundary", function()
      -- TODO: implement
    end)

    pending("does not expand a fixed min below a new value", function()
      -- TODO: implement
    end)

    pending("does not expand a fixed max above a new value", function()
      -- TODO: implement
    end)

    pending("handles the edge case where value lands exactly on a nice boundary", function()
      -- TODO: implement
    end)

  end)



  describe("get_min() / get_max()", function()

    pending("returns the fixed min/max when set explicitly", function()
      -- TODO: implement
    end)

    pending("returns huge/-huge before any push for dynamic range", function()
      -- TODO: implement
    end)

    pending("returns the snapped min after a push expands the lower bound", function()
      -- TODO: implement
    end)

    pending("returns the snapped max after a push expands the upper bound", function()
      -- TODO: implement
    end)

  end)



  describe("clear()", function()

    pending("empties the sample history", function()
      -- TODO: implement
    end)

    pending("resets dynamic min/max to sentinel values", function()
      -- TODO: implement
    end)

    pending("does not reset fixed min/max", function()
      -- TODO: implement
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
