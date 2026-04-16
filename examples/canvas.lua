local t = require "terminal"
local Canvas = require "terminal.ui.canvas"

-- 40 columns x 20 rows of braille cells (80x80 pixels)
local c = Canvas({ width = 40, height = 20 })

-- diagonal line across the full canvas
c:line(0, 0, 79, 79)

-- circle in the centre
c:circle(39, 39, 30)

-- smaller inverted circle (clear pixels) inside
c:circle(39, 39, 15, true)

-- make room and render in place
t.output.write(("\n"):rep(20))
t.cursor.position.up(20)
t.output.write(c:render())

-- move beyond the canvas
t.cursor.position.down(20)
