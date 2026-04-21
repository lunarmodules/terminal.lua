local t = require "terminal"
local Canvas = require "terminal.ui.canvas"
local sys = require "system"

-- 60 cols x 30 rows = 120 x 120 pixels (square: each braille pixel is ~4x4 real pixels)
local c = Canvas({ width = 60, height = 30 })



-- Draw a dashed circle by tracking arc-length in pixel steps (~1 pixel per step).
local function dashed_circle(canvas, cx, cy, r, dash, gap)
  local step    = 1.0 / r  -- one step ≈ one pixel of arc
  local drawing = true
  local toggle  = dash
  local px, py  -- previous pixel, to skip duplicate points

  local angle = 0
  while angle < 2 * math.pi + step do
    local x = math.floor(cx + r * math.cos(angle) + 0.5)
    local y = math.floor(cy + r * math.sin(angle) + 0.5)
    if drawing and (x ~= px or y ~= py) then
      canvas:set(x, y)
      px, py = x, y
    end
    toggle = toggle - 1
    if toggle <= 0 then
      drawing = not drawing
      toggle  = drawing and dash or gap
    end
    angle = angle + step
  end
end



-- Outer dashed ring
dashed_circle(c, 60, 60, 58, 12, 8)

-- Large filled blue circle, offset slightly lower-left of centre
c:circle({ x = 60, y = 60, r = 45, fill = true })

-- White "moon" highlight — erase a circle from the upper-right of the blue circle
c:circle({ x = 79, y = 37, r = 11, fill = true, erase = true })

-- Small satellite dot, upper-right between the two circles
c:circle({ x = 103, y = 14, r = 11, fill = true })



-- Make room and animate
t.output.print("Lua logo:")
t.output.write(("\n"):rep(30))
t.cursor.position.up(30)

for _ = 1, 61 do
  t.output.write(c:render())
  c:roll(1, 1)
  sys.sleep(0.05)
end

t.cursor.position.down(30)
