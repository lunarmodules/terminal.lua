-- This example writes a testscreen (background filled with numbers) and then
-- writes a box with a message inside.
-- It creates one very large string, and writes it at once to the terminal.
-- It uses the `output.write` function to do so safely with retries to ensure
-- that the entire string is written.

local t = require("terminal")
local Sequence = require("terminal.sequence")



local main do
  -- writes entire screen with numbers 1-9
  local function testscreen(o)
    local r, c = t.size()
    local row = ("1234567890"):rep(math.floor(c/10) + 1):sub(1, c)

    -- push a color on the stack
    o[#o+1] = t.text.stack.push_seq{
      fg = "red",
      brightness = "dim",
    }

    -- print all rows to fill the screen
    for i = 1, r do
      o[#o+1] = t.cursor.position.set_seq(i, 1)
      o[#o+1] = row
    end

    -- pop the color previously set, restoring the previous setting
    o[#o+1] = t.text.stack.pop_seq()
  end


  main = function()
    local o = Sequence()
    -- clear the screen, and draw the test screen
    o[#o+1] = t.clear.screen_seq()
    testscreen(o)

    -- draw a box, with 2 cols/rows margin around the screen
    local edge = 2
    local r,c = t.size()
    o[#o+1] = t.cursor.position.set_seq(edge+1, edge+1)
    o[#o+1] = t.draw.box_seq(r - 2*edge, c - 2*edge, t.draw.box_fmt.double, true,
              "test screen", nil, nil, { fg = "green", bg = "black", brightness = 3 })

    -- move cursor inside the box
    o[#o+1] = t.cursor.position.move_seq(1, 1)

    -- set text attributes (not using the stack this time)
    o[#o+1] = t.text.attr_seq{
      fg = "red",
      bg = "blue",
      brightness = 3,
    }
    o[#o+1] = "press any key, or wait 5 seconds..."

    -- write the whole thing at once
    assert(t.output.write(o))

    -- wait for user input, or timeout after 5 seconds
    t.input.readansi(5)
  end
end



-- initialize terminal; backup (switch to alternate buffer) and set output to stdout
t.initwrap(main, {
  displaybackup = true,
  filehandle = io.stdout,
})()



-- this is printed on the original screen buffer
print("done!")
