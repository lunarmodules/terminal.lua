-- An example of using `sequence` to create a reusable sequence of terminal commands.
-- This example uses the `textpushs` and `textpops` functions to change the text color.
-- By using functions instead of strings the color change is only active during the
-- execution of the sequence.

local t = require("terminal")
local Sequence = require("terminal.sequence")

-- print a green checkmark, without changing any other attributes
local greencheck = Sequence(
  function() return t.textpushs({ fg = "green" }) end, -- set green FG color AT TIME OF WRITING
  "✔", -- write a check mark
  t.textpops -- passing in function is enough, since no parameters needed
)


-- print a green checkmark at the top of the screen.
-- doesn't use a stack for cursor pos, but terminal memory
local top = Sequence(
  t.cursor_saves, -- save cursor position, no params, so passing function is ok
  t.cursor_sets(1,1), -- move to row 1, column 1
  greencheck, -- print the green checkmark, injecting another sequence
  t.cursor_restores -- restore cursor position, no params, so passing function is ok
)


-- print another one at pos 2,2, but now use the cursor positioning stack
-- this is safer, if the 'greencheck' sub-sequence would also use the
-- terminal memory for the cursor position (overwriting ours).
local top2 = Sequence(
  function() return t.cursor_pushs(2,2) end,
  greencheck, -- print the green checkmark
  t.cursor_pops
)


t.initialize()

-- print the green checkmarks, by default this will be on a black background
t.print(greencheck, " hello ", greencheck, " world ", greencheck) -- uses normal colors for the text
-- change background to red, and print again, the same sequence now properly prints on a red background
t.textpush({ bg = "red" })
t.write(greencheck, " hello ", greencheck, " world ", greencheck) -- text is on red background now
t.textpop() -- whilst the cursor is still on the same line, otherwise if scrolling the scrolled line will be red!
t.print() -- push the newline
-- print again, and the background is back to black
t.print(greencheck, " hello ", greencheck, " world ", greencheck) -- text is back to normal colors

-- print the green checkmark at the top of the screen
t.write(top)
t.write(top2) -- anotheer one at pos 2,2

t.shutdown()
