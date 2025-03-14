local terminal = require("terminal")

-- Initialize terminal
terminal.initialize()

-- Push state
terminal.push_state()
terminal.cursor_set(10, 10)
terminal.color_fg("red")
terminal.print("This text is red and at (10, 10)")

-- Pop state
terminal.pop_state()
terminal.print("This text is back to the original state")

-- Shutdown terminal
terminal.shutdown()