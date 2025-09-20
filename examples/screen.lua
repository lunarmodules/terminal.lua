#!/usr/bin/env lua

--- Screen example demonstrating full-screen terminal applications.
--
-- This example shows how to create and use Screen instances for
-- full-screen terminal applications with header, body, and footer.

local t = require("terminal")

local function main()
  local Screen = require("terminal.ui.screen")
  local Panel = require("terminal.ui.panel")

  -- Create header panel
  local header = Panel {
    min_height = 1,
    max_height = 1,
    content = function(self, row, col, height, width)
      t.cursor.position.backup()
      t.cursor.position.set(row, col)
      t.text.stack.push{
        fg = "white",
        bg = "blue",
        brightness = "bright",
      }
      t.output.write(" Hello white on blue World! ")
      t.clear.eol()
      t.text.stack.pop()
      t.cursor.position.restore()
    end
  }

  -- Create footer panel
  local footer = Panel {
    min_height = 1,
    max_height = 1,
    content = function(self, row, col, height, width)
      t.cursor.position.backup()
      t.cursor.position.set(row, col)
      t.text.stack.push{
        fg = "white",
        bg = "blue",
        brightness = "dim",
      }
      t.output.write(" Press 'q' to quit, or resize screen to redraw")
      t.clear.eol()
      t.text.stack.pop()
      t.cursor.position.restore()
    end
  }

  -- Create body panel
  local body = Panel {
    content = function(self, row, col, height, width)
      for i = 1, height do
        t.cursor.position.set(row + i - 1, col)
        t.output.write(
          string.format("Body content line %d of %d", i, height),
          t.clear.eol_seq()
        )
      end
    end
  }


  -- Create screen with all panels
  local screen = Screen {
    header = header,
    body = body,
    footer = footer,
    name = "ExampleScreen"
  }

  -- Initial render
  screen:calculate_layout()
  screen:render()

  -- Main loop
  while true do
    local input = t.input.readansi(0.2) -- 0.2 second timeout

    if input == "q" then
      break

    elseif input == nil then   -- Timeout - check for resize
      screen:check_resize(true)
    end
  end
end

-- initialize terminal; backup (switch to alternate buffer) and set output to stdout
t.initwrap(main, {
  displaybackup = true,
  filehandle = io.stdout,
})()

-- this is printed on the original screen buffer
print("done!")
