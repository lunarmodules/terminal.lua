#!/usr/bin/env lua

-- TextPanel example demonstrating scrollable text display

local TextPanel = require("src.terminal.ui.panel.text")
local terminal = require("terminal")
local Screen = require("src.terminal.ui.panel.screen")
local Panel = require("src.terminal.ui.panel")
local Bar = require("src.terminal.ui.panel.bar")

-- Create some sample text content
local sample_text = {
  "Welcome to the TextPanel example!",
  "",
  "This panel displays scrollable text content with the following features:",
  "",
  "• Text truncation for lines that are too long",
  "• Scrollable viewport when content exceeds panel height",
  "• Configurable scroll step size",
  "• Methods for navigation: set_position(), scroll_up(), scroll_down()",
  "• Dynamic content management: set_lines(), add_line(), clear()",
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

-- Create help text content
local help_text = {
  "Help:",
  "• Use 'h' to toggle this help",
  "• Use 'j' or ↓ arrow to scroll down",
  "• Use 'k' or ↑ arrow to scroll up",
  "• Use 'pgup' or 'pgdn' to page up/down",
  "• Use '[' and ']' to move the highlight",
  "• Use 'g' to go to top",
  "• Use 'G' to go to bottom",
  "• Use 'r' to add a random line",
  "• Use 'c' to clear content",
  "• Use 's' to reset to the sample text",
  "• Use 'f' to switch line-formatters; trunc, wrap, word-wrap",
  "• Use 'q' to quit",
}

-- Create the main content panel (left side)
local main_content = TextPanel {
  lines = sample_text,
  scroll_step = 1,
  text_attr = { fg = "white", brightness = "bright" },
  --highlight_attr = { fg = "red", brightness = "bright" },
  border = { format = terminal.draw.box_fmt.single },
  auto_render = true,
}

-- Create the help panel (right side)
local help_panel = TextPanel {
  lines = help_text,
  line_formatter = TextPanel.format_line_wordwrap,
  scroll_step = 1,
  text_attr = { fg = "cyan", brightness = "bright" },
  border = { format = terminal.draw.box_fmt.single },
  auto_render = true,
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

  body = Panel {         -- Create a horizontal split panel
    orientation = Panel.orientations.horizontal,
    children = { main_content, help_panel },
    split_ratio = 0.7,   -- Give more space to main content
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
      text = "h: help, q: quit",
      attr = { fg = "red", brightness = "bright" }
    },
    attr = { bg = "black", fg = "white" }
  }
}

local formatters = {
  TextPanel.format_line_truncate,
  TextPanel.format_line_wrap,
  TextPanel.format_line_wordwrap,
}
local current_formatter = 1

-- Main event loop
local function main()
  local keymap = terminal.input.keymap.default_key_map
  local keys = terminal.input.keymap.default_keys

  terminal.cursor.visible.set(false)
  screen:calculate_layout()
  screen:render()

  while true do
    local key = terminal.input.readansi(0.1)
    local keyname = keymap[key or ""]

    if key == "q" or key == "Q" then
      break
    elseif key == "h" or key == "H" then
      -- Toggle help panel visibility
      help_panel:hide(help_panel:visible())
      screen:calculate_layout()
      screen:render()
    elseif key == "j" or keyname == keys.down then
      main_content:scroll_down()
    elseif key == "k" or keyname == keys.up then
      main_content:scroll_up()
    elseif keyname == keys.pageup then
      main_content:page_up()
    elseif keyname == keys.pagedown then
      main_content:page_down()
    elseif key == "[" then
      main_content:set_highlight((main_content:get_highlight() or 2) - 1, true)
    elseif key == "]" then
      main_content:set_highlight((main_content:get_highlight() or 0) + 1, true)
    elseif key == "g" then
      main_content:set_position(1)
    elseif key == "G" then
      main_content:set_position(math.huge)
    elseif key == "f" then
      current_formatter = current_formatter % #formatters + 1
      main_content:set_line_formatter(formatters[current_formatter])
    elseif key == "r" then
      -- Add a random line
      local random_line = "Random line " .. math.random(1000) .. " added at " .. os.date("%H:%M:%S")
      main_content:add_line(random_line)
    elseif key == "c" then
      -- Clear content
      main_content:clear_lines()
    elseif key == "s" then
      -- Reset to sample text
      main_content:set_lines(sample_text)
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

