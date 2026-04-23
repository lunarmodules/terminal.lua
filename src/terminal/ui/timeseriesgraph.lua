--- A time-series graph drawn on a Canvas using a CanvasViewport.
--
-- Mixes two coordinate layers:
-- - A CanvasViewport (stretch) for the scaled data line.
-- - Direct canvas pixel drawing for fixed-size decorations: Y-axis (x=0),
--   tick marks (x=1), and an X-axis at the position of value 0.
--
-- The X-axis position adapts to the data range:
-- - Range straddles zero (e.g. -50..50): axis drawn at the midpoint.
-- - Entire range positive (e.g. 0..100): axis at the bottom.
-- - Entire range negative (e.g. -100..-10): axis at the top.
--
-- `min` and `max` can be omitted to make the range dynamic: it expands
-- automatically when a pushed value falls outside the current bounds,
-- snapping the new boundary to the nearest nice number.
-- @classmod ui.TimeSeriesGraph

local position = require "terminal.cursor.position"
local Sequence = require "terminal.sequence"
local Canvas = require "terminal.ui.canvas"
local utils = require "terminal.utils"
local text = require "terminal.text"
local CVP = require "terminal.ui.canvasviewport"




local utf8swidth = require("terminal.text.width").utf8swidth
local floor = math.floor
local huge = math.huge
local ceil = math.ceil
local log = math.log
local max = math.max
local min = math.min
local abs = math.abs



-- Round a raw interval up to the nearest "nice" number (1/2/5 × 10^n).
local function nice_interval(raw)
  if raw <= 0 then return 1 end
  local exp = floor(log(raw) / log(10))
  local mag = 10 ^ exp
  local normalized = raw / mag
  local factor
  if normalized <= 1 then factor = 1
  elseif normalized <= 2 then factor = 2
  elseif normalized <= 5 then factor = 5
  else factor = 10
  end
  return factor * mag
end



-- Smallest nice number (1/2/5 × 10^n) that is >= v.
local function nice_ceil(v)
  if v == 0 then return 0 end
  local exp = floor(log(abs(v)) / log(10))
  local mag = 10 ^ exp
  if v > 0 then
    local n = v / mag
    if n <= 1 then return 1 * mag
    elseif n <= 2 then return 2 * mag
    elseif n <= 5 then return 5 * mag
    else return 10 * mag
    end
  else
    local n = (-v) / mag  -- positive normalised value of abs(v)
    if n >= 5 then return -5 * mag
    elseif n >= 2 then return -2 * mag
    else return -1 * mag
    end
  end
end



-- Largest nice number (1/2/5 × 10^n) that is <= v.
local function nice_floor(v)
  if v == 0 then return 0 end
  local exp = floor(log(abs(v)) / log(10))
  local mag = 10 ^ exp
  if v > 0 then
    local n = v / mag
    if n >= 5 then return 5 * mag
    elseif n >= 2 then return 2 * mag
    else return 1 * mag
    end
  else
    local n = (-v) / mag  -- positive normalised value of abs(v)
    if n <= 1 then return -1 * mag
    elseif n <= 2 then return -2 * mag
    elseif n <= 5 then return -5 * mag
    else return -10 * mag
    end
  end
end



-- Generate evenly-spaced tick values that fall on nice numbers.
-- @param min_val data-domain minimum
-- @param max_val data-domain maximum
-- @param px_h canvas pixel height (determines how many ticks fit)
-- @param min_gap minimum pixels between ticks (default 8)
local function auto_ticks(min_val, max_val, px_h, min_gap)
  min_gap = min_gap or 8
  local max_ticks = floor(px_h / min_gap)
  if max_ticks < 1 then return {} end

  local interval = nice_interval((max_val - min_val) / max_ticks)
  local ticks = {}
  -- Start from the first multiple of interval that falls inside the range.
  local v = ceil(min_val / interval) * interval
  while v <= max_val + interval * 1e-9 do
    ticks[#ticks + 1] = v
    v = v + interval
  end
  return ticks
end



-- Map a data value to a physical Y pixel coordinate on the canvas.
local function data_to_py(value, min_val, range, px_h)
  if px_h <= 1 then return 0 end
  return floor((min_val + range - value) / range * (px_h - 1))
end



local TimeSeriesGraph = utils.class()



--- Create a new TimeSeriesGraph.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts
-- @tparam[opt=100] number opts.history sliding window size (number of samples)
-- @tparam[opt] number opts.min data-domain minimum, maps to the bottom of the graph;
--   when omitted the minimum expands dynamically as values are pushed
-- @tparam[opt] number opts.max data-domain maximum, maps to the top of the graph;
--   when omitted the maximum expands dynamically as values are pushed
-- @tparam[opt] table opts.ticks explicit Y-axis tick values in data units;
--   auto-generated from canvas height when omitted
-- @usage
-- local graph = TimeSeriesGraph({
--   history = 100,
--   min = 0,
--   max = 100,
--   ticks = { 25, 50, 75, 100 },  -- explicit tick values in data units
-- })
-- graph:push(42)
-- local output = graph:render({ cols = 60, rows = 15 })
function TimeSeriesGraph:init(opts)
  opts = opts or {}
  assert(type(opts) == "table", "opts must be a table")
  local history = opts.history
  if history == nil then
    history = 100
  else
    assert(type(history) == "number" and history > 0 and history % 1 == 0,
      "history must be a positive integer")
  end
  self._history_size = history
  self._ticks = opts.ticks -- nil → auto-generate per draw
  self._samples = {}

  -- Sentinel values signal that the bound is dynamic.
  -- huge / -huge compare correctly against any pushed value.
  self._dynamic_min = not opts.min
  self._dynamic_max = not opts.max
  self._min = opts.min or huge
  self._max = opts.max or -huge

  if not self._dynamic_min and not self._dynamic_max then
    assert(self._max > self._min, "max must be greater than min")
  end
end



--- Return the current data-domain minimum.
-- For dynamic ranges this reflects the nicely-snapped lower bound after pushes.
-- @treturn number
function TimeSeriesGraph:get_min()
  return self._min
end



--- Return the current data-domain maximum.
-- For dynamic ranges this reflects the nicely-snapped upper bound after pushes.
-- @treturn number
function TimeSeriesGraph:get_max()
  return self._max
end



--- Add a data sample. Drops the oldest sample when the window is full.
-- For dynamic min/max, expands the range to the next nice boundary when the
-- value falls outside the current bounds.
-- @tparam number value
function TimeSeriesGraph:push(value)
  assert(type(value) == "number", "value must be a number")
  self._samples[#self._samples + 1] = value
  if #self._samples > self._history_size then
    table.remove(self._samples, 1)
  end

  if self._dynamic_min and value < self._min then
    self._min = nice_floor(value)
  end
  if self._dynamic_max and value > self._max then
    self._max = nice_ceil(value)
  end

  -- Edge case: value sits exactly on a nice boundary so floor == ceil.
  if self._min >= self._max then
    if self._dynamic_max then self._max = self._min + 1 end
    if self._dynamic_min then self._min = self._max - 1 end
  end
end



--- Reset the sample history.
-- Dynamic min/max bounds are also reset to their initial sentinel values.
function TimeSeriesGraph:clear()
  self._samples = {}
  if self._dynamic_min then self._min = huge end
  if self._dynamic_max then self._max = -huge end
end



--- Draw the graph onto an existing Canvas.
-- @tparam Canvas canvas already sized by the caller
function TimeSeriesGraph:draw(canvas)
  -- Nothing to draw until at least one push has established a valid range.
  if self._min >= self._max then return end

  local px_h, px_w = canvas:get_pixels()
  local min_v = self._min
  local max_v = self._max
  local range = max_v - min_v

  -- 1. Data line through viewport (scales with the canvas).
  --    Virtual space: x = sample index 0..history-1, y = 0..100 inclusive
  --    (0 = top), so the viewport height must be 101.
  local vp = CVP({
    canvas = canvas,
    width = self._history_size,
    height = 101,
    scale_mode = "stretch",
  })

  if #self._samples > 1 then
    local points = {}
    for i, v in ipairs(self._samples) do
      points[i] = { i - 1, (max_v - v) / range * 100 }
    end
    vp:polygon({ points = points, open = true })
  end

  -- 2. Y-axis: full-height vertical line at physical x=0.
  canvas:line({ x1 = 0, y1 = 0, x2 = 0, y2 = px_h - 1 })

  -- 3. X-axis: horizontal line at the physical pixel row for value = 0.
  --    Clamped so it stays visible even when 0 is outside the data range.
  local x_axis_y = max(0, min(px_h - 1,
    data_to_py(0, min_v, range, px_h)))
  canvas:line({ x1 = 0, y1 = x_axis_y, x2 = px_w - 1, y2 = x_axis_y })

  -- 4. Tick marks: 1-pixel nods at physical x=1, always on top of graph content.
  local ticks = self._ticks or auto_ticks(min_v, max_v, px_h)
  for _, tick_v in ipairs(ticks) do
    local tick_y = data_to_py(tick_v, min_v, range, px_h)
    if tick_y >= 0 and tick_y < px_h then
      canvas:set(1, tick_y)
    end
  end
end



--- Convenience wrapper: create a Canvas, draw, and return the render string.
-- When `opts.fmt` is given, min/max labels are drawn to the left of the graph;
-- the canvas is narrowed automatically to keep the total width equal to `opts.cols`.
-- @tparam table opts
-- @tparam number opts.cols total width in display-columns (labels + graph)
-- @tparam number opts.rows total height in display-rows
-- @tparam[opt] string opts.fmt `string.format` pattern for the min/max labels (e.g. `"%g"` or `"%d%%"`);
-- when given, labels are drawn to the left of the graph
-- @tparam[opt] table opts.graph_attr text attributes for the graph area (e.g. `{ fg = "cyan" }`)
-- @tparam[opt] table opts.label_attr text attributes for the min/max labels (e.g. `{ fg = "white" }`)
-- @treturn Sequence terminal escape sequence string ready for `output.write`
-- @usage
-- output.write(graph:render({
--   cols = 60,
--   rows = 15,
--   fmt = "%d%%",
--   graph_attr = { fg = "cyan" },
--   label_attr = { fg = "white" },
-- }))
function TimeSeriesGraph:render(opts)
  opts = opts or {}
  local cols = opts.cols
  local rows = opts.rows
  local fmt = opts.fmt or ""
  local graph_attr = opts.graph_attr
  local label_attr = opts.label_attr

  local has_range = self._min < self._max

  local lbl_max = ""
  local lbl_min = ""
  local label_width = 0

  if rows < 2 or cols <= (label_width + 1) then
    -- Not enough space for graph content, drop the labels
    fmt = ""
  end

  if fmt ~= "" and has_range then
    lbl_max = string.format(fmt, self._max)
    lbl_min = string.format(fmt, self._min)
    local max_w, min_w = utf8swidth(lbl_max), utf8swidth(lbl_min)
    label_width = max(max_w, min_w)
    -- align labels right
    lbl_max = (" "):rep(label_width - max_w) .. lbl_max
    lbl_min = (" "):rep(label_width - min_w) .. lbl_min
  end

  local blank_label_line = (" "):rep(label_width) .. position.down_seq(1) .. position.left_seq(label_width)

  -- Draw graph on a canvas
  local c = Canvas({
    width = cols - label_width,
    height = rows
  })
  self:draw(c)

  -- create a sequence to return
  local s = Sequence(
    -- format the labels
    label_attr and function() return text.push_seq(label_attr) end or "",
    -- max-label
    lbl_max,
    position.down_seq(1),
    position.left_seq(label_width),
    -- clear inbetween lines
    blank_label_line:rep(rows - 2),
    -- min-label
    lbl_min,
    -- move up for the graph render, undo attributes
    position.up_seq(rows - 1),
    label_attr and text.pop_seq or "",
    -- draw the graph, with graph_attr if given
    graph_attr and function() return text.push_seq(graph_attr) end or "",
    c:render(),
    graph_attr and text.pop_seq or "",
    -- return to start column after graph render
    position.left_seq(label_width)
  )

  return s
end



return TimeSeriesGraph
