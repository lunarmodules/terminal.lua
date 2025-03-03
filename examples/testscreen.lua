-- This example writes a testscreen (background filled with numbers) and then
-- writes a box with a message inside.

local sys = require("system")
local t = require("terminal")


-- writes entire screen with numbers 1-9
local function testscreen()
  local r, c = sys.termsize()
  local row = ("1234567890"):rep(math.floor(c/10) + 1):sub(1, c)

  -- push a color on the stack
  t.textpush{
    fg = "red",
    brightness = "dim",
  }

  -- print all rows to fill the screen
  for i = 1, r do
    t.cursor_set(i, 1)
    t.write(row)
  end

  -- pop the color previously set, restoring the previous setting
  t.textpop()
end




-- initialize terminal; backup (switch to alternate buffer) and set output to stdout
t.initialize(true, io.stdout)

-- clear the screen, and draw the test screen
t.clear()
testscreen()

-- draw a box, with 2 cols/rows margin around the screen
local edge = 2
local r,c = sys.termsize()
t.cursor_set(edge+1, edge+1)
t.box(r - 2*edge, c - 2*edge, t.box_fmt.double, true, "test screen")

-- move cursor inside the box
t.cursor_move(1, 1)

-- set text attributes (not using the stack this time)
t.textset{
  fg = "red",
  bg = "blue",
  brightness = 3,
}
t.write("Hello World! press any key, or wait 5 seconds...")
t.flush()
t.readansi(5)

-- restore all settings (reverts to original screen buffer)
t.shutdown()

-- this is printed on the original screen buffer
print("done!")
