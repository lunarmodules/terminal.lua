#!/usr/bin/env lua

-- TextPanel example demonstrating scrollable text display

local TextPanel = require("src.terminal.ui.panel.text_panel")
local Screen = require("src.terminal.ui.panel.screen")
local Bar = require("src.terminal.ui.panel.bar")
local terminal = require("terminal")

-- Create some sample text content
local sample_text = {
  "Welcome to the TextPanel example!",
  "",
  "This panel displays scrollable text content with the following features:",
  "",
  "• Text truncation for lines that are too long",
  "• Scrollable viewport when content exceeds panel height",
  "• Configurable scroll step size",
  "• Methods for navigation: go_to(), scroll_up(), scroll_down()",
  "• Dynamic content management: set_lines(), add_line(), clear()",
  "",
  "Navigation:",
  "• Use 'j' or ↓ arrow to scroll down",
  "• Use 'k' or ↑ arrow to scroll up",
  "• Use 'g' to go to top",
  "• Use 'G' to go to bottom",
  "• Use 'r' to add a random line",
  "• Use 'c' to clear content",
  "• Use 's' to reset to this sample text",
  "• Use 'q' to quit",
  "",
  "The TextPanel class inherits from Panel and provides:",
  "",
  "• Automatic text truncation using terminal.text.width",
  "• Viewport management for large text content",
  "• Integration with the Panel layout system",
  "• Support for borders and text attributes",
  "",
  "This is a long line that should be truncated when the panel width is insufficient to display the entire content. The truncation respects UTF-8 character boundaries and double-width characters.",
  "",
  "More content follows:",
  "Line " .. string.rep("A", 50),
  "Line " .. string.rep("B", 30),
  "Line " .. string.rep("C", 40),
  "Line " .. string.rep("D", 20),
  "Line " .. string.rep("E", 60),
  "",
  "You can add more lines dynamically:",
  "• Call add_line() to append new content",
  "• Call set_lines() to replace all content",
  "• Call clear() to remove all content",
  "",
  "The panel automatically handles:",
  "• Empty lines and nil content",
  "• Position clamping to valid ranges",
  "• Efficient rendering (only when content changes)",
  "",
  "This concludes the TextPanel demonstration.",
  "Thank you for trying out this example!"
}

-- Create the main screen
local screen = Screen {
  header = Bar {
    left = {
      text = "TextPanel Example",
      attr = { fg = "cyan", brightness = "bright" }
    },
    center = {
      text = "Scrollable Text Display",
      attr = { fg = "yellow", brightness = "bright", underline = true }
    },
    right = {
      text = "Press 'q' to quit",
      attr = { fg = "green", brightness = "bright" }
    },
    attr = { bg = "blue" }
  },

  body = TextPanel {
    lines = sample_text,
    scroll_step = 1,
    text_attr = { fg = "white", brightness = "bright" },
    border = { format = terminal.draw.box_fmt.single },
    auto_render = true,
  },

  footer = Bar {
    left = {
      text = "j/k or ↑/↓: scroll",
      attr = { fg = "magenta", brightness = "bright" }
    },
    center = {
      text = "pgup/pgdn: page, g/G: top/bottom",
      attr = { fg = "yellow", brightness = "bright" }
    },
    right = {
      text = "q: quit",
      attr = { fg = "red", brightness = "bright" }
    },
    attr = { bg = "black", fg = "white" }
  }
}

-- Main event loop
local function main()
  local keymap = terminal.input.keymap.default_key_map
  local keys = terminal.input.keymap.default_keys

  screen:calculate_layout()
  screen:render()

  while true do
    local key = terminal.input.readansi(0.1)
    local keyname = keymap[key or ""]

    if key == "q" or key == "Q" then
      break
    elseif key == "j" or keyname == keys.down then
      screen:get_panel("body"):scroll_down()
    elseif key == "k" or keyname == keys.up then
      screen:get_panel("body"):scroll_up()
    elseif keyname == keys.pageup then
      screen:get_panel("body"):page_up()
    elseif keyname == keys.pagedown then
      screen:get_panel("body"):page_down()
    elseif key == "g" then
      screen:get_panel("body"):go_to(1)
    elseif key == "G" then
      screen:get_panel("body"):go_to(screen:get_panel("body"):get_line_count())
    elseif key == "r" then
      -- Add a random line
      local random_line = "Random line " .. math.random(1000) .. " added at " .. os.date("%H:%M:%S")
      screen:get_panel("body"):add_line(random_line)
    elseif key == "c" then
      -- Clear content
      screen:get_panel("body"):clear_lines()
    elseif key == "s" then
      -- Reset to sample text
      screen:get_panel("body"):set_lines(sample_text)
    end

    -- Check for resize, and redraw if needed
    screen:check_resize(true)
  end
end

-- Initialize terminal and run the example
terminal.initwrap(main, {
  displaybackup = true,
  filehandle = io.stdout,
})()

