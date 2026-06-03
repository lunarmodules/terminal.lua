--- A multi-choice interactive checkbox widget for CLI tools.
--
-- This module provides a way to create a checkbox list, allowing the user
-- to toggle multiple options using Space, navigate with arrow keys, and
-- confirm with Enter. Type-ahead search navigates to a matching entry.
-- The selected options are highlighted, and the user can confirm with Enter.
-- Optionally the widget can be cancelled by pressing `<esc>` or `<ctrl+c>`.
--
-- NOTE: you MUST call `terminal.initialize` before calling this widget's `:run()` method.
--
-- *Usage:*
--     local menu = cli.MultiSelect{
--       prompt = "Select options:",
--       choices = {
--         { label = "Option 1", key = "opt1", value = false },
--         { label = "Option 2", key = "opt2", value = true },
--         { label = "Option 3", value = false },  -- key defaults to label
--       },
--       cancellable = true
--     }
--
--     local result = menu()  -- invokes the 'run' method
--     -- result = { opt1 = false, opt2 = true, ["Option 3"] = false }
-- @classmod cli.MultiSelect

local t = require("terminal")
local EditLine = require("terminal.editline")
local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")

local MultiSelect = utils.class()



-- TODO: add min/max selection constraints (e.g. require at least 1, or at most N)
-- TODO: add mutually-exclusive groups (selecting one unchecks others in the group)
-- TODO: add mutually-required groups (selecting one forces others in the group on)



-- Key bindings
local keys = t.input.keymap.get_keys()
local ctrl_c = assert(t.input.keymap.get_raw_key("ctrl_c"))
local keymap = t.input.keymap.get_keymap({
  [ctrl_c] = keys.escape, -- remap Ctrl+C --> Esc
})



-- UI symbols (including trailing whitespace)
local filled_diamond = "◆ "
local diamond = "◇ "
local checked_default   = "■ "
local unchecked_default = "□ "
local pipe    = "│  "
local angle   = "└  "



--- Create a new MultiSelect instance.
-- @tparam table opts Options for the MultiSelect widget.
-- @tparam table opts.choices List of choices. Each entry is a table with:
--   `label` (string, required), `key` (any type, optional, defaults to label),
--   `value` (boolean, optional, initial checked state, defaults to false).
-- @tparam[opt=1] number opts.default Default choice index (1-based).
-- @tparam[opt="Select options:"] string opts.prompt Prompt message to display.
-- @tparam[opt=false] boolean opts.cancellable Whether the widget can be cancelled (by pressing `<esc>` or `<ctrl+c>`).
-- @tparam[opt=false] boolean opts.clear Whether to clear the widget from screen after completion.
-- @tparam[opt=1.0] number opts.typeahead_delay Seconds of inactivity after which the typeahead search buffer resets.
-- @tparam[opt="● "] string opts.checked_sym Symbol displayed in front of a checked item.
-- @tparam[opt="○ "] string opts.unchecked_sym Symbol displayed in front of an unchecked item.
-- @treturn MultiSelect A new MultiSelect instance.
-- @name cli.MultiSelect
function MultiSelect:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(type(opts.choices) == "table", "choices must be a table")
  assert(#opts.choices > 0, "choices must not be empty")
  for _, choice in ipairs(opts.choices) do
    assert(type(choice) == "table", "each choice must be a table")
    assert(type(choice.label) == "string", "each choice must have a string label")
  end
  self.choices = opts.choices

  self.prompt = opts.prompt or "Select options:"
  assert(type(self.prompt) == "string", "prompt must be a string")

  self.cancellable = not not opts.cancellable
  self.clear = not not opts.clear
  self.typeahead_delay = opts.typeahead_delay or 1.0

  self.checked_sym = opts.checked_sym or checked_default
  self.unchecked_sym = opts.unchecked_sym or unchecked_default
  assert(type(self.checked_sym) == "string", "checked_sym must be a string")
  assert(type(self.unchecked_sym) == "string", "unchecked_sym must be a string")

  self.default = opts.default or 1
  assert(type(self.default) == "number", "default must be a number")
  assert(self.default >= 1 and self.default <= #self.choices, "default out of range")

  self.checked = {}
  for i, choice in ipairs(self.choices) do
    self.checked[i] = not not choice.value
  end

  self.selected = self.default

  self:template()
end



-- Allow instance to be called directly
function MultiSelect:__call()
  return self:run()
end



-- Build full UI sequence
function MultiSelect:template()
  local res = Sequence(
    function() return t.cursor.position.up_seq():rep(self:height()) end,
    function() return t.text.push_seq({ fg = "green" }) end,
    function() return self.selected and diamond or filled_diamond end,
    t.text.pop_seq,
    self.prompt,
    t.clear.eol_seq,
    "\n"
  )

  for i, option in ipairs(self.choices) do
    res = res + Sequence(
      i == #self.choices and angle or pipe,
      function() return self.checked[i] and self.checked_sym or self.unchecked_sym end,
      function()
        return t.text.push_seq({
          fg = (i == self.selected) and "yellow" or "white",
          brightness = (i == self.selected) and "normal" or "dim"
        })
      end,
      option.label,
      t.text.pop_seq,
      t.clear.eol_seq,
      "\n"
    )
  end

  self.__template = res
end



-- Read and normalize key input
function MultiSelect:readKey(timeout)
  local rawkey, keytype = t.input.readansi(timeout)
  return rawkey, keymap[rawkey] or rawkey, keytype
end



-- Find first choice whose label prefix matches the current search buffer (case-insensitive).
-- Starts at self.selected (inclusive) and wraps around. Returns self.selected if no match.
function MultiSelect:_findMatch()
  local prefix = tostring(self._search):lower()

  if #prefix == 0 then
    return self.selected
  end

  local n = #self.choices
  for i = 0, n - 1 do
    local idx = (self.selected - 1 + i) % n + 1
    if self.choices[idx].label:lower():sub(1, #prefix) == prefix then
      return idx
    end
  end

  return self.selected
end



-- Handle input loop and navigation
function MultiSelect:handleInput()
  self._search = EditLine{}

  local cancelled = false
  while true do
    t.output.write(self.__template)

    local timeout = self._search:len_char() > 0 and self.typeahead_delay or math.huge
    local rawkey, keyName, keytype = self:readKey(timeout)

    if rawkey == nil then
      -- timeout (or error): reset search buffer
      self._search:clear()

    elseif keyName == keys.backspace or keyName == keys.del then
      -- backspace: trim search buffer if active, otherwise ignore
      if self._search:len_char() > 0 then
        self._search:backspace()
        self.selected = self:_findMatch()
      end

    elseif rawkey == " " then
      -- space: clear typeahead buffer and toggle current item
      self._search:clear()
      self.checked[self.selected] = not self.checked[self.selected]

    elseif keytype == "char" then
      self._search:insert(rawkey)
      self.selected = self:_findMatch()

    elseif keyName == keys.up then
      self._search:clear()
      self.selected = math.max(1, self.selected - 1)

    elseif keyName == keys.down then
      self._search:clear()
      self.selected = math.min(#self.choices, self.selected + 1)

    elseif keyName == keys.escape and self.cancellable then
      self._search:clear()
      cancelled = true
      break

    elseif keyName == keys.enter then
      self._search:clear()
      local s = self.selected
      self.selected = nil  -- prevent rendering the cursor in the final output
      t.output.write(self.__template)
      self.selected = s
      break
    end
  end

  if cancelled then
    return nil, "cancelled"
  end

  local result = {}
  for i, choice in ipairs(self.choices) do
    local key = choice.key ~= nil and choice.key or choice.label
    result[key] = self.checked[i]
  end
  return result
end



--- Returns the display height in rows.
-- @treturn number The height of the widget in rows.
function MultiSelect:height()
  if not self.widths then
    self.widths = {}
    for i, choice in ipairs(self.choices) do
      self.widths[i] = t.text.width.utf8swidth(pipe .. self.unchecked_sym .. choice.label)
    end
    self.widths[0] = t.text.width.utf8swidth(diamond .. self.prompt)
  end

  local _, cols = t.size()
  local rows = 0
  for i = 0, #self.choices do
    rows = rows + math.ceil(self.widths[i] / cols)
  end
  return rows
end



--- Clears the widget.
function MultiSelect:clear_widget()
  t.output.write(
    t.cursor.position.up_seq():rep(self:height()),
    (t.clear.eol_seq() .. "\n"):rep(self:height()),
    t.cursor.position.up_seq():rep(self:height())
  )
end



--- Prints a one-line summary showing the count of checked items.
function MultiSelect:print_selection()
  local count = 0
  for i = 1, #self.choices do
    if self.checked[i] then count = count + 1 end
  end
  t.output.write(
    t.text.push_seq({ fg = "green" }),
    filled_diamond,
    t.text.pop_seq(),
    self.prompt,
    " ",
    t.text.push_seq({ fg = "yellow", brightness = "dim" }),
    count .. " selected (of " .. #self.choices .. ")",
    t.text.pop_seq(),
    t.clear.eol_seq(),
    "\n"
  )
end



--- Set the current selection index.
-- @tparam number idx The index to set as the current selection (1-based).
function MultiSelect:set_selection(idx)
  assert(type(idx) == "number", "selection index must be a number")
  assert(idx >= 1 and idx <= #self.choices, "selection index out of range")
  self.selected = idx
end



--- Executes the widget.
-- @treturn[1] table Hash table `{ [key] = bool }` for each choice
-- @treturn[2] nil If cancelled.
-- @treturn[2] string Error string `"cancelled"` if cancelled.
function MultiSelect:run()
  -- Reserve space for rendering
  t.output.write(("\n"):rep(#self.choices + 1))
  t.cursor.visible.push(false)

  local result, err = self:handleInput()

  if self.clear then
    self:clear_widget()
  end

  t.cursor.visible.pop()

  return result, err
end



return MultiSelect
