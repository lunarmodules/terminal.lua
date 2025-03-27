-- This example writes a testscreen (background filled with numbers) and then
-- writes a box with a message inside.

local t = require("terminal")


-- writes entire screen with numbers 1-9
local function testscreen()
  local r, c = t.size()
  local row = ("1234567890"):rep(math.floor(c/10) + 1):sub(1, c)

  -- push a color on the stack
  t.text.stack.push{
    fg = "red",
    brightness = "dim",
  }

  -- print all rows to fill the screen
  for i = 1, r do
    t.cursor.position.set(i, 1)
    t.output.write(row)
  end

  -- pop the color previously set, restoring the previous setting
  t.text.stack.pop()
end




-- initialize terminal; backup (switch to alternate buffer) and set output to stdout
t.initialize{
  displaybackup = true,
  filehandle = io.stdout,
}

-- clear the screen, and draw the test screen
t.clear.screen()
testscreen()

-- draw a box, with 2 cols/rows margin around the screen
local edge = 2
local r,c = t.size()
t.cursor.position.set(edge+1, edge+1)
t.draw.box(r - 2*edge, c - 2*edge, t.draw.box_fmt.double, true, "test screen")

-- move cursor inside the box
t.cursor.position.move(1, 1)

-- set text attributes (not using the stack this time)
t.text.attr{
  fg = "red",
  bg = "blue",
  brightness = 3,
}
t.output.write("Hello World! press any key, or wait 5 seconds...")
t.output.flush()
t.input.readansi(5)

-- restore all settings (reverts to original screen buffer)
t.shutdown()

-- this is printed on the original screen buffer
print("done!")
