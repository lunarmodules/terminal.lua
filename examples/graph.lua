--- Time-series graph demo using TimeSeriesGraph.
--
-- Plots a slow sine wave to demonstrate dynamic min/max scaling,
-- axis placement, and label rendering.
--
-- Run with: lua examples/graph.lua
-- Press any key to quit.

local t               = require "terminal"
local TimeSeriesGraph = require "terminal.canvas.timeseriesgraph"

local HISTORY_SIZE = 100   -- number of samples kept / displayed
local INTERVAL     = 0.10  -- seconds between updates
local GRAPH_COLS   = 60    -- canvas width in braille character columns (= 120 px)
local GRAPH_ROWS   = 15    -- canvas height in braille character rows   (=  60 px)

local frame = 0   -- counts updates; use frame * INTERVAL for wall time

local graph = TimeSeriesGraph({
  history = HISTORY_SIZE,
})



--- Returns the next data sample: a slow sine wave in the range -100..100.
local function get_value()
  frame = frame + 1
  return 100 * math.sin(frame * INTERVAL * 0.8)
end



local function main()
  t.cursor.visible.set(false)
  t.output.print("Sine wave demo  (press any key to quit)")
  t.output.write(("\n"):rep(GRAPH_ROWS + 2))
  t.cursor.position.up(GRAPH_ROWS + 2)

  while true do
    graph:push(get_value())
    t.output.write(graph:render({
      cols = GRAPH_COLS,
      rows = GRAPH_ROWS,
      fmt = "%g%%",
      graph_attr = { fg = "black", bg = "yellow" },
      label_attr = { fg = "red", bg = "white" },
    }))

    if t.input.readansi(INTERVAL) then
      break
    end
  end

  t.cursor.position.down(GRAPH_ROWS)
  t.output.print("\nDone.")
  t.cursor.visible.set(true)
end



-- initialize terminal and run
t.initwrap(main)()
