#!/usr/bin/env lua

-- TabStrip example demonstrating tabbed interface with TabStrip and PanelSet

local TabStrip = require("src.terminal.ui.panel.tab_strip")
local Set = require("src.terminal.ui.panel.set")
local terminal = require("terminal")
local Screen = require("src.terminal.ui.panel.screen")
local Panel = require("src.terminal.ui.panel")
local Bar = require("src.terminal.ui.panel.bar")
local TextPanel = require("src.terminal.ui.panel.text")

-- Create sample content for each tab
local tab_contents = {
  overview = {
    "Welcome to the TabStrip Example!",
    "",
    "This example demonstrates:",
    "",
    "• TabStrip panel for displaying tab labels",
    "• PanelSet for managing tab content panels",
    "• Integration between TabStrip and PanelSet",
    "• Keyboard navigation between tabs",
    "",
    "Use the following keys to navigate:",
    "• Left/Right arrows or h/l to switch tabs",
    "• Tab/Shift+Tab to move between tabs",
    "• q to quit",
    "",
    "The TabStrip automatically handles:",
    "• Viewport scrolling when tabs overflow",
    "• Visual highlighting of selected tab",
    "• Smooth navigation between tabs",
  },
  features = {
    "TabStrip Features:",
    "",
    "• Horizontal tab label display",
    "• Viewport scrolling for many tabs",
    "• Configurable prefix/postfix (default: [])",
    "• Customizable attributes for selected/unselected tabs",
    "• Callback support for selection changes",
    "• Methods: select(), select_next(), select_prev()",
    "",
    "PanelSet Features:",
    "",
    "• Manages multiple named panels",
    "• Shows one panel at a time",
    "• Automatic selection management",
    "• Methods: select(), get_selected(), add(), remove()",
    "",
    "Integration:",
    "",
    "• TabStrip select_cb connects to PanelSet:select()",
    "• Keyboard input controls TabStrip selection",
    "• PanelSet automatically shows/hides panels",
  },
  content = {
    "Content Tab",
    "",
    "This is the content tab. You can put any panel content here.",
    "",
    "The panels in the PanelSet can be:",
    "• TextPanel (like this one)",
    "• Regular Panel with custom content",
    "• Nested panels with complex layouts",
    "",
    "Each tab can have completely different content and layout.",
    "",
    "Try switching between tabs to see different content!",
  },
  settings = {
    "Settings Tab",
    "",
    "This tab could contain:",
    "• Configuration options",
    "• User preferences",
    "• Application settings",
    "",
    "For this example, it's just another TextPanel.",
    "",
    "In a real application, you might have:",
    "• Input fields",
    "• Checkboxes",
    "• Dropdown menus",
    "• Other interactive elements",
  },
  help = {
    "Help Tab",
    "",
    "Keyboard Shortcuts:",
    "",
    "Navigation:",
    "  ← / h    - Previous tab",
    "  → / l    - Next tab",
    "  Tab      - Next tab",
    "  Shift+Tab - Previous tab",
    "",
    "General:",
    "  q / Q    - Quit application",
    "",
    "The TabStrip will automatically scroll to show",
    "the selected tab if there are many tabs.",
  }
}

-- Create content panels for each tab
local tab_panels = {}
for tab_id, content in pairs(tab_contents) do
  tab_panels[tab_id] = TextPanel {
    name = tab_id,
    lines = content,
    scroll_step = 1,
    text_attr = { fg = "white", brightness = "bright" },
    border = { format = terminal.draw.box_fmt.single },
    auto_render = true,
    min_height = 1,  -- Ensure minimum height, 1 line considering 2 lines for border
    min_width = 4,  -- Ensure minimum width, 2 chars (or 1 double width) and 2 for the border
  }
end

-- Create PanelSet with all tab panels
local tab_set = Set {
  children = {
    tab_panels.overview,
    tab_panels.features,
    tab_panels.content,
    tab_panels.settings,
    tab_panels.help,
  },
  selected = "overview",
}

-- Create TabStrip with items matching the panels
local tab_strip = TabStrip {
  items = {
    { id = "overview", label = "Overview" },
    { id = "features", label = "Features" },
    { id = "content", label = "Content" },
    { id = "settings", label = "Settings" },
    { id = "help", label = "Help" },
  },
  selected = "overview",
  attr = { fg = "white", bg = "black" },
  selected_attr = { fg = "black", bg = "cyan", brightness = "bright" },
  select_cb = function(self, tab_id)
    -- When tab is selected in TabStrip, select corresponding panel in PanelSet
    tab_set:select(tab_id)
  end,
  auto_render = true,
  padding = 2,
  prefix = "┌",
  postfix = "┐",
}

-- Create the main screen
local screen = Screen {
  header = Panel {       -- Header with TabStrip
    orientation = Panel.orientations.vertical,
    children = {
      Bar {
        left = {
          text = "TabStrip Example",
          attr = { fg = "cyan", brightness = "bright" }
        },
        center = {
          text = "Tabbed Interface Demo",
          attr = { fg = "yellow", brightness = "bright", underline = true }
        },
        right = {
          text = "Press 'q' to quit",
          attr = { fg = "green", brightness = "bright" }
        },
        attr = { bg = "blue" }
      },
      tab_strip
    },
    split_ratio = 0.6,   -- Give Bar 60%, TabStrip 40% (both need 1 line minimum)
  },

  body = tab_set,  -- Body contains the PanelSet with tab content

  footer = Bar {
    left = {
      text = "←/→ or h/l: switch tabs",
      attr = { fg = "magenta", brightness = "bright" }
    },
    center = {
      text = "Tab/Shift+Tab: navigate",
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

  terminal.cursor.visible.set(false)
  screen:calculate_layout()
  screen:render()

  -- Debug: Check TabStrip dimensions (can be removed later)
  -- print(string.format("TabStrip: row=%d, col=%d, height=%d, width=%d, inner_height=%d, inner_width=%d",
  --   tab_strip.row or 0, tab_strip.col or 0, tab_strip.height or 0, tab_strip.width or 0,
  --   tab_strip.inner_height or 0, tab_strip.inner_width or 0))

  while true do
    local key = terminal.input.readansi(0.1)
    local keyname = keymap[key or ""]

    if key == "q" or key == "Q" then
      break
    elseif key == "h" or keyname == keys.left then
      -- Previous tab
      tab_strip:select_prev()
      screen:calculate_layout()  -- Recalculate layout after tab switch
      screen:render()
    elseif key == "l" or keyname == keys.right then
      -- Next tab
      tab_strip:select_next()
      screen:calculate_layout()  -- Recalculate layout after tab switch
      screen:render()
    elseif keyname == keys.tab then
      -- Next tab (Tab key)
      tab_strip:select_next()
      screen:calculate_layout()  -- Recalculate layout after tab switch
      screen:render()
    elseif keyname == keys.shift_tab then
      -- Previous tab (Shift+Tab)
      tab_strip:select_prev()
      screen:calculate_layout()  -- Recalculate layout after tab switch
      screen:render()
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

