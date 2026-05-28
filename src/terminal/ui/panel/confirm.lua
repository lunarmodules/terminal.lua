--- Confirmation dialog.
--
-- Creates a modal dialog that sizes itself to the terminal: the width is
-- derived from the ButtonBar's preferred display size, and the text area
-- height from word-wrapping the prompt to that width.
--
-- The button items, `ids`, and `sets` fields share the same format as
-- `ui.panel.ButtonBar` and `cli.Confirm`.
--
-- Call `:run()` to display the dialog and block until the user confirms or
-- cancels. On confirmation the `id` of the selected button is returned. On
-- cancellation `nil, "cancelled"` is returned.
--
-- This Panel class is standalone, similar to `Screen`, it is not intended to
-- be embedded inside another Panel as a child.
--
-- Example:
--
--     local Confirm = require("terminal.ui.panel.confirm")
--     local terminal = require("terminal")
--
--     local dlg = Confirm {
--       prompt   = "Delete this file?",
--       buttons  = Confirm.sets.yes_no_cancel,
--       border   = {
--         format = terminal.draw.box_fmt.rounded,
--         title  = "Confirm",
--       },
--     }
--
--     local id, err = dlg:run()
--     if id == Confirm.ids.yes then
--       -- proceed
--     end
--
-- @classmod ui.panel.Confirm

local utils     = require("terminal.utils")
local Panel     = require("terminal.ui.panel")
local t         = require("terminal")
local width     = require("terminal.text.width")
local ButtonBar = require("terminal.ui.panel.button_bar")
local TextPanel = require("terminal.ui.panel.text")
local keys      = t.input.keymap.get_keys()
local key_map   = t.input.keymap.default_key_map



local Confirm = utils.class(Panel)



-- Border format for the text panel: blank top row and 2-space left/right sides, no bottom.
-- Mirrors the button bar's blank border so text and buttons share the same indentation.
local TEXT_BORDER_FMT = (function()
  local fmt = t.draw.box_fmt.blank:copy()
  fmt.b  = ""
  fmt.bl = fmt.l
  fmt.br = fmt.r
  return fmt
end)()
local TEXT_BORD_W = width.utf8swidth(TEXT_BORDER_FMT.l or "") + width.utf8swidth(TEXT_BORDER_FMT.r or "")
local TEXT_BORD_H = (TEXT_BORDER_FMT.t ~= "" and 1 or 0) + (TEXT_BORDER_FMT.b ~= "" and 1 or 0)



--- Response ID constants. Shared with `ButtonBar.ids` and `cli.Confirm.ids`.
-- @table Confirm.ids
Confirm.ids = ButtonBar.ids



--- Preset item sets ready to pass as `opts.items`.
-- Shared with `ButtonBar.sets` and `cli.Confirm.sets`.
-- @table Confirm.sets
Confirm.sets = ButtonBar.sets



--- Create a new Confirm dialog instance.
-- @tparam table opts Options.
-- @tparam string|table opts.prompt The question or message shown in the text area.
-- A plain string is used as a single line. Alternatively supply an array of strings.
-- @tparam table opts.buttons Array of button items. Each entry must have a `label`
-- (string) and may have an `id` (any; defaults to the item index) and
-- `cancel` (boolean; marks the button selected on Escape).
-- @tparam[opt] any opts.default Id of the initially focused button.
-- Defaults to the first item.
-- @tparam[opt] boolean opts.cancellable Whether ESC/Ctrl+C is allowed.
-- Defaults to `true` when an item has `cancel = true`, `false` otherwise.
-- @tparam[opt] table opts.border Border configuration for the dialog. Inherits
-- the same structure as `Panel`'s border option (format, attr, title, title_attr,
-- truncation_type).
-- @tparam[opt] string opts.prefix Passed to ButtonBar: string prepended to each button label, default: `"["`.
-- @tparam[opt] string opts.postfix Passed to ButtonBar: string appended to each button label, default: `"]"`.
-- @tparam[opt=1] number opts.padding Passed to ButtonBar: spaces between adjacent buttons.
-- @tparam[opt] number opts.button_min_width Passed to ButtonBar.
-- @tparam[opt] number opts.button_max_width Passed to ButtonBar.
-- @tparam[opt] table opts.attr Text attributes applied to the dialog background
-- and prompt text.
-- @tparam[opt] table opts.button_attr Passed to ButtonBar: unselected button attributes.
-- @tparam[opt] table opts.selected_attr Passed to ButtonBar: focused button attributes.
-- @tparam[opt] function opts.redraw Called before each dialog render (including on
-- resize) and once after `:run()` exits. Use it to repaint the underlying screen
-- so the dialog always draws on a fresh background and the screen is restored on exit.
-- @treturn Confirm A new Confirm dialog instance.
-- @name ui.panel.Confirm
function Confirm:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(type(opts.prompt) == "string" or type(opts.prompt) == "table", "prompt must be a string or table of strings")
  assert(type(opts.buttons) == "table" and #opts.buttons > 0, "buttons must be a non-empty table")
  assert(opts.redraw == nil or type(opts.redraw) == "function", "redraw must be a function")

  local prompt_lines = type(opts.prompt) == "string" and { opts.prompt } or opts.prompt

  -- cancellable: true when a cancel-marked button exists (unless explicitly overridden)
  local has_cancel = false
  for _, btn in ipairs(opts.buttons) do
    if btn.cancel then
      has_cancel = true
      break
    end
  end
  local cancellable
  if opts.cancellable ~= nil then
    cancellable = not not opts.cancellable
  else
    cancellable = has_cancel
  end

  local bar = ButtonBar {
    items            = opts.buttons,
    selected         = opts.default,
    border           = {
      format = t.draw.box_fmt.blank,
      attr   = opts.attr,
    },
    prefix           = opts.prefix,
    postfix          = opts.postfix,
    padding          = opts.padding,
    button_min_width = opts.button_min_width,
    button_max_width = opts.button_max_width,
    attr             = opts.attr,
    button_attr      = opts.button_attr,
    selected_attr    = opts.selected_attr,
    auto_render      = true,
  }

  local text = TextPanel {
    lines          = prompt_lines,
    line_formatter = TextPanel.format_line_wordwrap,
    text_attr      = opts.attr,
    border         = {
      format = TEXT_BORDER_FMT,
      attr = opts.attr,
    },
  }

  Panel.init(self, {
    orientation = Panel.orientations.vertical,
    children    = { text, bar },
    border      = opts.border,
  })

  self.prompt          = opts.prompt
  self._prompt_lines   = prompt_lines
  self.cancellable     = cancellable
  self._bar            = bar
  self._text           = text
  self._redraw         = opts.redraw
  self._last_screen_h  = 0
  self._last_screen_w  = 0
end



-- Allow the instance to be called directly, invoking `:run()`.
function Confirm:__call()
  return self:run()
end



--- Returns the id of the currently focused button.
-- @treturn any The focused button id.
function Confirm:get_selection()
  return self._bar:get_selection()
end



-- Compute the dialog position and dimensions from the current terminal size.
-- Determines dialog width from the ButtonBar's preferred display width, word-wraps
-- the prompt at that width to compute the text area height, then positions both
-- child panels within the dialog bounds via the outer panel.
-- Called automatically by `:run()` before the first render and on each resize.
function Confirm:calculate_layout()
  local screen_h, screen_w = t.size()

  -- Border overhead from the dialog's own border (shared by both child panels).
  local bord_w, bord_h = 0, 0
  if self.border then
    local fmt = self.border.format
    bord_w = width.utf8swidth(fmt.l or "") + width.utf8swidth(fmt.r or "")
    if fmt.t ~= "" then bord_h = bord_h + 1 end
    if fmt.b ~= "" then bord_h = bord_h + 1 end
  end

  -- Preferred outer dialog width: ButtonBar inner content width plus border chars.
  local pref_inner_w = self._bar:preferred_min_width()
  local pref_outer_w = pref_inner_w + bord_w

  -- Aim for the midpoint between the screen and the preferred minimum: avoids a
  -- dialog that fills the whole terminal for short prompts, without going narrower
  -- than what the buttons need.
  local dialog_w = math.floor((screen_w + pref_outer_w) / 2)
  dialog_w = math.max(pref_outer_w, math.min(screen_w, dialog_w))

  -- Shrink further if all prompt lines are shorter than the candidate width,
  -- but never below the button bar's preferred minimum.
  local max_prompt_w = 0
  for _, line in ipairs(self._prompt_lines) do
    local lw = width.utf8swidth(line)
    if lw > max_prompt_w then max_prompt_w = lw end
  end
  if dialog_w > max_prompt_w + TEXT_BORD_W + bord_w then
    dialog_w = math.max(pref_outer_w, max_prompt_w + TEXT_BORD_W + bord_w)
  end

  -- Compute text panel height by word-wrapping the prompt at the text content width.
  local inner_w = dialog_w - bord_w
  local text_inner_h = 0
  for _, line in ipairs(self._prompt_lines) do
    text_inner_h = text_inner_h + #self._text:format_line_wordwrap(line, inner_w - TEXT_BORD_W)
  end

  -- Total outer dialog height: text outer rows + button bar rows + dialog border rows.
  local bar_h   = self._bar._min_height
  local dialog_h = text_inner_h + TEXT_BORD_H + bar_h + bord_h

  -- Center the dialog on the screen.
  local dialog_row = math.max(1, math.floor((screen_h - dialog_h) / 2) + 1)
  local dialog_col = math.max(1, math.floor((screen_w - dialog_w) / 2) + 1)

  -- Delegate to Panel: sets self.row/col/height/width, computes the inner area,
  -- and distributes height between the text and button children automatically.
  Panel.calculate_layout(self, dialog_row, dialog_col, dialog_h, dialog_w)
end



--- Display the dialog and block until the user makes a selection.
-- Handles Left/Right to navigate buttons, Enter to confirm, and
-- ESC/Ctrl+C to cancel. On each iteration the terminal size is compared
-- to the last known size; if it changed the layout is recalculated and the
-- dialog is re-rendered before processing the key.
-- @treturn[1] any The `id` of the selected button.
-- @treturn[1] nil
-- @treturn[2] nil On success with an explicit cancel button.
-- @treturn[2] string `"cancelled"` when ESC is pressed and no cancel button
-- exists but `cancellable` is `true`.
function Confirm:run()
  t.cursor.visible.push(false)

  -- Initial draw: lay out and render without invoking redraw.
  do
    local h, w = t.size()
    self._last_screen_h = h
    self._last_screen_w = w
    self:calculate_layout()
    self:render()
  end

  local result, err
  while true do
    local cur_h, cur_w = t.size()
    if cur_h ~= self._last_screen_h or cur_w ~= self._last_screen_w then
      self._last_screen_h = cur_h
      self._last_screen_w = cur_w
      self:calculate_layout()
      if self._redraw then self._redraw() end
      self:render()
    end

    local rawkey = t.input.readansi(0.1)
    local keyname = key_map[rawkey]

    if keyname == keys.right then
      self._bar:select_next()

    elseif keyname == keys.left then
      self._bar:select_prev()

    elseif keyname == keys.enter then
      result = self._bar:get_selection()
      break

    elseif (keyname == keys.escape or keyname == keys.ctrl_c) and self.cancellable then
      result, err = self._bar:select_cancel()
      if err then
        -- there was no cancel button, but we are cancellable, so return the cancelled error
        err = "cancelled" -- rewrite error message
        result = nil
      end
      break
    end
  end

  t.cursor.visible.pop()
  if self._redraw then self._redraw() end
  return result, err
end



return Confirm
