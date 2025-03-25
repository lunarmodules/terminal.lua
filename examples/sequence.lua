-- An example of using `sequence` to create a reusable sequence of terminal commands.
-- This example uses the `text.stack.pushs` and `text.stack.pops` functions to change the text color.
-- By using functions instead of strings the color change is only active during the
-- execution of the sequence.

local t = require("terminal")
local Sequence = require("terminal.sequence")

-- print a green checkmark, without changing any other attributes
local greencheck = Sequence(
  function() return t.text.stack.push_seq({ fg = "green" }) end, -- set green FG color AT TIME OF WRITING
  "✔", -- write a check mark
  t.text.stack.pop_seq -- passing in function is enough, since no parameters needed
)


-- print a green checkmark at the top of the screen.
-- doesn't use a stack for cursor pos, but terminal memory
local top = Sequence(
  t.cursor.position.backup_seq, -- save cursor position, no params, so passing function is ok
  t.cursor.position.set_seq(1,1), -- move to row 1, column 1
  greencheck, -- print the green checkmark, injecting another sequence
  t.cursor.position.restore_seq -- restore cursor position, no params, so passing function is ok
)


-- print another one at pos 2,2, but now use the cursor positioning stack
-- this is safer, if the 'greencheck' sub-sequence would also use the
-- terminal memory for the cursor position (overwriting ours).
local top2 = Sequence(
  function() return t.cursor.position.stack.push_seq(2,2) end,
  greencheck, -- print the green checkmark
  t.cursor.position.stack.pop_seq
)


t.initialize()

-- print the green checkmarks, by default this will be on a black background
t.output.write(greencheck, " hello ", greencheck, " world ", greencheck, "\n") -- uses normal colors for the text
-- change background to red, and print again, the same sequence now properly prints on a red background
t.text.stack.push({ bg = "red" })
t.output.write(greencheck, " hello ", greencheck, " world ", greencheck) -- text is on red background now
t.text.stack.pop() -- whilst the cursor is still on the same line, otherwise if scrolling the scrolled line will be red!
t.output.write("\n") -- push the newline
-- print again, and the background is back to black
t.output.write(greencheck, " hello ", greencheck, " world ", greencheck, "\n") -- text is back to normal colors

-- print the green checkmark at the top of the screen
t.output.write(top)
t.output.write(top2) -- anotheer one at pos 2,2

t.shutdown()
