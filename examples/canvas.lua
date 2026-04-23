local t = require "terminal"
local Canvas = require "terminal.ui.canvas"
local CanvasViewport = require "terminal.ui.canvasviewport"

-- Virtual coordinate space: matches the original Lua-logo geometry
-- (original canvas was 60×30 cells → 120×120 pixels)
local VIRT_W = 120
local VIRT_H = 120

-- Cycling lists for the two render options
local scale_modes = {
  CanvasViewport.scale_modes.fit,
  CanvasViewport.scale_modes.fill,
  CanvasViewport.scale_modes.stretch,
}
local anchors = {
  CanvasViewport.anchors.center,
  CanvasViewport.anchors.top_left,
}

local scale_idx = 1
local anchor_idx = 1



-- Draw a dashed circle through the viewport by walking arc-length (~1 pixel per step).
local function dashed_circle(vp, cx, cy, r, dash, gap)
  local step = 1.0 / r
  local drawing = true
  local toggle = dash
  local px, py

  local angle = 0
  while angle < 2 * math.pi + step do
    local x = math.floor(cx + r * math.cos(angle) + 0.5)
    local y = math.floor(cy + r * math.sin(angle) + 0.5)
    if drawing and (x ~= px or y ~= py) then
      vp:set(x, y)
      px, py = x, y
    end
    toggle = toggle - 1
    if toggle <= 0 then
      drawing = not drawing
      toggle = drawing and dash or gap
    end
    angle = angle + step
  end
end



local function draw_logo(vp)
  -- Outer dashed ring
  dashed_circle(vp, 60, 60, 58, 12, 8)
  -- Large filled circle, offset slightly lower-left of centre
  vp:circle({ x = 60, y = 60, r = 45, fill = true })
  -- "Moon" highlight — erase a circle from the upper-right of the blue circle
  vp:circle({ x = 79, y = 37, r = 11, fill = true, erase = true })
  -- Small satellite dot, upper-right between the two circles
  vp:circle({ x = 103, y = 14, r = 11, fill = true })
end



local function make_canvas(rows, cols)
  -- Reserve the last row for the status bar
  local canvas_rows = rows - 1
  local c = Canvas({ width = cols, height = canvas_rows })
  local vp = CanvasViewport({
    canvas = c,
    width = VIRT_W,
    height = VIRT_H,
    scale_mode = scale_modes[scale_idx],
    anchor = anchors[anchor_idx],
  })
  draw_logo(vp)
  return c
end



local function redraw(c, rows, cols)
  -- Render the canvas starting at top-left; render() returns cursor to (1,1)
  t.cursor.position.set(1, 1)
  t.output.write(c:render())

  -- Status bar on the last row
  t.cursor.position.set(rows, 1)
  t.output.write(string.format(
    " [s] scale: %-8s  [a] anchor: %-8s  any other key: quit",
    scale_modes[scale_idx], anchors[anchor_idx]
  ))
end



local function main()
  t.cursor.visible.set(false)

  local rows, cols = t.size()
  local c = make_canvas(rows, cols)
  redraw(c, rows, cols)

  local running = true
  while running do
    local rawkey = t.input.readansi(0.1)

    -- Check for terminal resize
    local new_rows, new_cols = t.size()
    if new_rows ~= rows or new_cols ~= cols then
      rows, cols = new_rows, new_cols
      c = make_canvas(rows, cols)
      redraw(c, rows, cols)
    end

    if rawkey then
      if rawkey == "s" then
        scale_idx = (scale_idx % #scale_modes) + 1
        c = make_canvas(rows, cols)
        redraw(c, rows, cols)
      elseif rawkey == "a" then
        anchor_idx = (anchor_idx % #anchors) + 1
        c = make_canvas(rows, cols)
        redraw(c, rows, cols)
      else
        running = false
      end
    end
  end

  t.cursor.visible.set(true)
end



-- initialize terminal and run
t.initwrap(main, { displaybackup = true })()
