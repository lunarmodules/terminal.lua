--- Prompt input for CLI tools.
--
-- This module provides a simple way to read line input from the terminal. The user can
-- confirm their choices by pressing &lt;Enter&gt; or cancel their choices by pressing &lt;Esc&gt;
-- (when cancellable is enabled).
--
-- Features: Prompt, UTF8 support, async input, (to be added: secrets, scrolling and wrapping)
--
-- NOTE: you MUST call `terminal.initialize` before calling this widget's `:run()` method.
--
-- *Usage:*
--     local prompt = Prompt {
--         prompt = "Enter something: ",
--         value = "Hello, 你-好 World 🚀!",
--         max_length = 62,
--         -- overflow = "wrap" -- or "scroll"   -- TODO: implement
--         cancellable = true,
--         position = 2,
--     }
--     local result, exitkey = prompt:run()
-- @classmod cli.Prompt

local t = require("terminal")
local utils = require("terminal.utils")
local width = require("terminal.text.width")
local output = require("terminal.output")
local EditLine = require("terminal.editline")
local Sequence = require("terminal.sequence")
local utf8 = require("utf8") -- explicitly requires lua-utf8 for Lua < 5.3

local unpack = unpack or table.unpack -- lua 5.1 compatibility: unpack is global in 5.1, table.unpack in 5.2+

-- Key bindings
local keys = t.input.keymap.get_keys()
local keymap = t.input.keymap.get_keymap()

local nop = function() end

local Prompt = utils.class()

Prompt.keyname2actions = {
  -- The value is the method name on the EditLine instance to invoke for this key.
  ["ctrl_?"] = "backspace",
  ["left"] = "left",
  ["right"] = "right",
  ["up"] = "up",
  ["down"] = "down",
  ["home"] = "goto_home",
  ["end"] = "goto_end",
  -- emacs keybinding
  ["ctrl_f"] = "left",
  ["alt_b"] = "left_word",
  ["ctrl_b"] = "right",
  ["alt_f"] = "right_word",
  ["ctrl_a"] = "goto_home",
  ["ctrl_e"] = "goto_end",
  ["ctrl_h"] = "backspace",
  ["ctrl_u"] = "backspace_to_start",
  ["ctrl_w"] = "backspace_word",
  ["ctrl_d"] = "delete",
  ["ctrl_k"] = "delete_to_end",
  ["alt_d"] = "delete_word",
  ["ctrl_l"] = "clear",
  -- other keybindings
  ["ctrl_left"] = "left_word",
  ["ctrl_right"] = "right_word",
  -- ["ctrl_backspace ???"] = "backspace_word", -- TODO: if backspace is ctrl + h, how does ctrl + backspace work?
  -- ["ctrl_delete ???"] -- TODO: same as above
}



-- Allow instance to be called directly
function Prompt:__call()
  return self:run()
end



--- Create a new Prompt instance.
-- @tparam table opts Options for the prompt.
-- @tparam[opt=""] string|EditLine opts.prompt The prompt text to display.
-- @tparam[opt=""] string|EditLine opts.value The initial value of the prompt (truncated if too long).
-- @tparam[opt] number opts.position The initial cursor position (in char) of the input (default at the end).
-- @tparam[opt=80] number opts.max_length The maximum length of the input.
-- @tparam[opt] string opts.word_delimiters Word delimiters for word operations.
-- @tparam[opt] table opts.text_attr Text attributes for the prompt (input value only).
-- @tparam[opt=false] boolean opts.wordwrap Whether to wordwrap the input value.
-- @tparam[opt=false] boolean opts.cancellable When true, pressing &lt;Esc&gt; cancels
-- the input and `run()` returns nil, "cancelled".
-- @treturn Prompt A new Prompt instance.
-- @name cli.Prompt
function Prompt:init(opts)
  local value = opts.value or ""
  if getmetatable(value) ~= EditLine then
    -- it is not an EditLine object, so create one
    value = EditLine({
      value = value,
      word_delimiters = opts.word_delimiters,
      position = opts.position,
    })
  elseif opts.position then
    -- existing EditLine object, so move cursor into correct position (if given)
    value:goto_index(opts.position)
  end

  self.value = value
  self.prompt = tostring(opts.prompt or "") -- the prompt to display
  self.prompt_width = width.utf8swidth(self.prompt) -- the width of the prompt in characters
  self.max_length = opts.max_length or 80   -- the maximum length of the input
  self.text_attr = opts.text_attr or {} -- text attributes for the input value
  self.wordwrap = not not opts.wordwrap -- whether to wordwrap the input value
  self.cancellable = not not opts.cancellable -- whether to allow the user to cancel the input

  if self.value:len_char() > self.max_length then
    -- truncate the value if it is too long, keep cursor position
    local pos = self.value:pos_char()
    self.value = self.value:sub_char(1, self.max_length)
    self.value:goto_index(pos)
  end

  -- cached data
  self.screen_rows = 0 -- the number of rows in the terminal screen
  self.screen_cols = 0 -- the number of columns in the terminal screen
  self.current_lines = {} -- the current formatted lines of the prompt
  self.cursor_row = 1 -- the row where the cursor is currently located
  self.cursor_col = 1 -- the column where the cursor is currently located
end



-- -- local debug function
-- -- @tparam number ln The line number to set the cursor to.
-- -- @tparam string ... The values to print.
-- local function dbg(ln, ...)
--   t.cursor.position.backup()
--   t.cursor.position.set(ln,1)
--   print(...)
--   t.cursor.position.restore()
-- end

-- -- local debug function
-- -- @tparam number ln The line number to set the cursor to.
-- -- @tparam string ... The values to print.
-- local function ping()
--   t.output.write(
--     t.text.stack.push_seq { fg = "red", brightness = "high", blink = true },
--     "*",
--     t.text.stack.pop_seq(),
--     t.cursor.position.left_seq()
--   )
--  t.input.readansi(math.huge) -- wait for any key
-- end



-- updates cached data; terminal size, cursor pos, formatted lines.
-- @return nothing
function Prompt:renew_cached_data()
  self.screen_rows, self.screen_cols = t.size()
  self.current_lines, self.cursor_row, self.cursor_col = self.value:format {
    width = self.screen_cols,
    first_width = self.screen_cols - self.prompt_width,
    wordwrap = self.wordwrap,
    pad = true,
    pad_last = false,
    no_new_cursor_line = false,
  }
end



-- Draw the whole thing: prompt and input value.
-- Moves the current cursor back to the top and writes the prompt and input value.
-- Repositions the cursor at the proper place in the current input value.
-- @return nothing
function Prompt:draw()
  -- move cursor to top
  local old_row = self.cursor_row
  -- local old_col = self.cursor_col

  self:renew_cached_data()

  local s = Sequence(
    -- move cursor to top
    t.cursor.position.column_seq(1),
    t.cursor.position.up_seq(old_row - 1),

    -- prompt
    self.prompt,

    -- current value in proper format
    function() return t.text.stack.push_seq(self.text_attr) end,
    Sequence(unpack(self.current_lines)), -- all lines concatenated (we formatted using padding, so should properly wrap)
    t.text.stack.pop_seq,
    t.clear.eol_seq(),        -- clear the remainder of the last line

    -- move cursor into position
    t.cursor.position.up_seq(#self.current_lines - self.cursor_row),
    t.cursor.position.column_seq(self.cursor_col)
  )

  output.write(s)
end



--- Processes key input async
-- This function listens for key events and processes them.
-- @return string "returned" or "cancelled" based on the key pressed.
function Prompt:handleInput()
  -- TODO: this should support "exitKeys"
  while true do
    local rawkey, keytype = t.input.readansi(math.huge)
    if rawkey then
      local keyname = keymap[rawkey] or rawkey
      local action = Prompt.keyname2actions[keyname]

      if action then
        local method = self.value[action] or nop
        method(self.value)

      elseif keyname == keys.escape and self.cancellable then
        return "cancelled"

      elseif keyname == keys.enter then
        return "returned"

      elseif keytype ~= "char" then
        t.bell()

      elseif self.value:len_char() >= self.max_length or utf8.len(keyname) ~= 1 then
        t.bell()

      else -- add the character at the current cursor
        self.value:insert(keyname)
      end

      -- update UI
      self:draw()
    end
  end
end



--- Starts the prompt input loop.
-- This function initializes the input loop for the readline instance.
-- It uses a coroutine to process key input until an exit key is pressed.
-- @treturn string|nil
--   The final input value entered by the user, or nil if the input was cancelled.
-- @treturn string
--   The exit status that terminated the input loop: "returned" or "cancelled".
function Prompt:run()
  local status

  self:draw()
  status = self:handleInput()
  t.output.print() -- move to new line (we're still on the 'press any key' line)

  if status == "returned" then
    return tostring(self.value), status
  else
    return nil, status
  end
end



return Prompt
