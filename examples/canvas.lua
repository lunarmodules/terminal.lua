local Canvas = require "terminal.ui.canvas"

local c = Canvas.new(80, 40)  -- 80x40 pixels = 40x10 braille cells

-- draw a diagonal
for i = 0, 39 do
  c:set(i * 2, i)
end

-- print to terminal
for _, line in ipairs(c:render()) do
  print(line)
end
