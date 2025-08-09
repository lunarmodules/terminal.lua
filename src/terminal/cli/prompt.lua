--- Prompt input for CLI tools.
--
-- This module provides a simple way to read line input from the terminal. The user can
-- confirm their choices by pressing &lt;Enter&gt; or cancel their choices by pressing &lt;Esc&gt;.
--
-- Features: Prompt, UTF8 support, async input, (to be added: secrets, scrolling and wrapping)
--
-- NOTE: you MUST `terminal.initialize` before calling this widget's `:run()` method.
--
-- *Usage:*
--     local prompt = Prompt {
--         prompt = "Enter something: ",
--         value = "Hello, 你-好 World 🚀!",
--         max_length = 62,
--         -- overflow = "wrap" -- or "scroll"   -- TODO: implement
--         -- cancellable = true,                -- TODO: implement
--         position = 2,
--     }
--     local result, exitkey = pr:run()
-- @classmod cli.Prompt

local t = require("terminal")
local utils = require("terminal.utils")
local width = require("terminal.text.width")
local output = require("terminal.output")
local EditLine = require("terminal.editline")
local utf8 = require("utf8") -- explicitly requires lua-utf8 for Lua < 5.3

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
  -- ["ctrl_deelte ???"] -- TODO: same as above
}

Prompt.actions2redraw = utils.make_lookup("actions", {
  ["backspace"] = true,
  ["delete"] = true,
  ["backspace_word"] = true,
  ["backspace_to_start"] = true,
  ["delete_word"] = true,
  ["delete_to_end"] = true,
  ["clear"] = true,
  --
  ["left"] = false,
  ["left_word"] = false,
  ["right_word"] = false,
  ["right"] = false,
  ["up"] = false,
  ["down"] = false,
  ["goto_home"] = false,
  ["goto_end"] = false,
})


-- inline completeness test, to help future self to keep the above tables in sync
for _, action in pairs(Prompt.keyname2actions) do
  if Prompt.actions2redraw[action] == nil then
    error("Missing redraw action in 'actions2redraw' for: " .. action)
  end
end



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
  self.max_length = opts.max_length or 80   -- the maximum length of the input

  if self.value:len_char() > self.max_length then
    -- truncate the value if it is too long, keep cursor position
    local pos = self.value:pos_char()
    self.value = self.value:sub_char(1, self.max_length)
    self.value:goto_index(pos)
  end
end


--- Draw the whole thing: prompt and input value.
-- This function writes the prompt and the current input value to the terminal.
-- @return nothing
function Prompt:draw()
  output.write(
    t.cursor.visible.set_seq(false),
    t.cursor.position.column_seq(1),
    self.prompt,
    self.value,
    t.clear.eol_seq()
  )
  self:updateCursor()
end


--- Draw the input value where the prompt ends.
-- This function writes input value to the terminal.
-- @return nothing
function Prompt:drawInput()
  output.write(
    t.cursor.visible.set_seq(false),
    t.cursor.position.column_seq(width.utf8swidth(self.prompt) + 1),
    self.value,
    t.clear.eol_seq()
  )
  self:updateCursor()
end


-- Update the cursor position.
-- This function moves the cursor to the current position based on the prompt and input value.
-- @tparam number column The column to move the cursor to. If not provided, it defaults to the end of
-- the prompt plus the current input value cursor position.
-- @return nothing
function Prompt:updateCursor(column)
  column = column or (width.utf8swidth(self.prompt) + self.value:pos_col())
  t.cursor.position.column(column)
  t.cursor.visible.set(true)
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
        local redraw = Prompt.actions2redraw[action]
        local method = self.value[action] or nop
        method(self.value)

        if redraw then
          self:drawInput()
        else
          self:updateCursor()
        end

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
        self:drawInput()
      end
    end
  end
end


--- Starts the prompt input loop.
-- This function initializes the input loop for the readline instance.
-- It uses a coroutine to process key input until an exit key is pressed.
-- @tparam boolean redraw Whether to redraw the prompt initially.
-- @treturn string The final input value entered by the user.
-- @treturn string The exit key that terminated the input loop.
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
