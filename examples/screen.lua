#!/usr/bin/env lua

--- Screen example demonstrating full-screen terminal applications with Bar class.
--
-- This example shows how to create and use Screen instances for
-- full-screen terminal applications with Bar-based header and footer,
-- showcasing the Bar class features including sub-table structure,
-- individual text attributes, truncation types, and styling options.

local t = require("terminal")

local function main()
  local Screen = require("terminal.ui.panel.screen")
  local Panel = require("terminal.ui.panel")
  local Bar = require("terminal.ui.panel.bar")

  -- Create header bar with multiple features
  local header = Bar {
    margin = 1,
    padding = 3,
    left = {
      text = "File",
      type = "left",
      attr = { fg = "cyan", brightness = "bright" }
    },
    center = {
      text = "Terminal Editor",
      type = "right",
      attr = { fg = "yellow", brightness = "bright", underline = true }
    },
    right = {
      text = "Help",
      type = "drop",
      attr = { fg = "green", brightness = "bright" }
    },
    attr = { bg = "blue" }
  }

  -- Create footer bar with different styling
  local footer = Bar {
    margin = 0,
    padding = 2,
    left = {
      text = "Status: Ready",
      type = "left",
      attr = { fg = "white", brightness = "dim" }
    },
    center = {
      text = "Press 'q' to quit",
      type = "right",
      attr = { fg = "white", brightness = "bright" }
    },
    right = {
      text = "Resize to redraw",
      type = "drop",
      attr = { fg = "white", brightness = "dim" }
    },
    attr = { bg = "blue", brightness = "dim" }
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
