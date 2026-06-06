#!/usr/bin/env lua

--- Example: ui.panel.Confirm dialog with a fullscreen layout.
--
-- Runs a sequence of Confirm dialogs in a loop. Each result is appended to a
-- scrolling log in the body before the next dialog opens, so you can see the
-- history build up.
--
-- Dialogs demonstrated:
--   1. Wide ButtonBar — four buttons padded to a large minimum width.
--   2. Word-wrapped prompt — a long message that wraps inside the dialog box.
--
-- Press ESC or Ctrl+C inside any dialog to cancel and exit.

local t       = require("terminal")
local Screen  = require("terminal.ui.panel.screen")
local Bar     = require("terminal.ui.panel.bar")
local TextPanel = require("terminal.ui.panel.text")
local Confirm = require("terminal.ui.panel.confirm")



-- Scrolling result log displayed in the body panel
local log = TextPanel {
  lines     = { "Select a button in each dialog.  ESC or Ctrl+C cancels and quits." },
  text_attr = { fg = "white" },
}

local screen = Screen {
  header = Bar {
    left   = { text = "ui.panel.Confirm Demo",    attr = { fg = "cyan",   brightness = "bright" } },
    center = { text = "Confirm Dialog Examples",  attr = { fg = "yellow", brightness = "bright", underline = true } },
    right  = { text = "ESC / Ctrl+C to quit",     attr = { fg = "white",  brightness = "dim" } },
    attr   = { bg = "blue" },
  },
  body = log,
  footer = Bar {
    center = {
      text = "← → navigate   Enter confirm   ESC / Ctrl+C cancel",
      attr = { fg = "white", brightness = "normal" },
    },
    attr = { bg = "blue", brightness = "dim" },
  },
}



-- Dialog factory functions — recreated each iteration so focus resets.
local dialogs = {

  -- 1. Wide ButtonBar: four buttons with a generous minimum width so the
  --    button row dominates the dialog and each label has breathing room.
  {
    label = "Wide ButtonBar",
    make  = function()
      return Confirm {
        prompt  = "Pick an action:",
        buttons = {
          { label = "Abort",      id = Confirm.ids.abort,    cancel = true },
          { label = "Retry",      id = "retry" },
          { label = "Ignore",     id = "ignore" },
          { label = "Report Bug", id = "report" },
        },
        button_min_width = 14,
        cancellable      = true,
        redraw = function()
          -- On resize, redraw the screen behind the dialog so the button bar always draws on a clean background.
          screen:calculate_layout()
          screen:render()
        end,
        border = {
          format = t.draw.box_fmt.rounded,
          title  = "Wide ButtonBar",
        },
      }
    end,
  },

  -- 2. Word-wrapped prompt: the long message is broken at word boundaries
  --    to fill the dialog width naturally.
  {
    label = "Word-Wrapped Prompt",
    make  = function()
      return Confirm {
        prompt = {
          "This is a longer prompt that demonstrates automatic word-wrapping. " ..
          "The text is broken at word boundaries to fit the dialog width, so even " ..
          "a paragraph-length message stays readable inside the box. " ..
          "Consider this before proceeding with the operation.",
          "",
          "It also supports multiple lines:",
          "• and 🚀 Rockets 💥 are supported too!",
          "• And if the dialog is wide enough, this line will stay on one line. Otherwise, it will wrap like the others.",
        },
        buttons = {
          { label = "Confirm", id = "confirm" },
          { label = "Cancel",  id = Confirm.ids.cancel, cancel = true },
        },
        attr = { fg = "white", bg = "blue" },
        button_attr = { fg = "yellow" },
        selected_attr = { fg = "yellow", brightness = "bright", reverse = true },
        cancellable = true,
        redraw = function()
          -- On resize, redraw the screen behind the dialog so the button bar always draws on a clean background.
          screen:calculate_layout()
          screen:render()
        end,
        border = {
          format = t.draw.box_fmt.rounded,
          title  = "Word-Wrapped Prompt",
          attr = { fg = "white", bg = "blue" },
        },
      }
    end,
  },

}



local function main()
  screen:calculate_layout()
  screen:render()

  local idx = 1

  while true do
    screen:check_resize(true)

    local entry = dialogs[idx]
    local id, err = entry.make():run()

    if id == Confirm.ids.cancel or id == Confirm.ids.abort then
      log:add_line(string.format("[%s]  cancelled (%s)", entry.label, tostring(err)))
      log:set_position(math.huge)
      screen:render()
      break
    end

    log:add_line(string.format("[%s]  selected '%s'", entry.label, tostring(id)))
    log:set_position(math.huge)
    screen:render()

    idx = idx % #dialogs + 1
  end
end



t.initwrap(main, {
  displaybackup  = true,
  filehandle     = io.stdout,
  disable_sigint = true,   -- route Ctrl+C through the input system so dialogs can catch it
})()

print("done!")
