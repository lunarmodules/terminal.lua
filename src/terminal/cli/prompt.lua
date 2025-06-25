--- Prompt input for CLI tools.
--
-- This module provides a simple way to read line input from the terminal. The user can
-- confirm their choices by pressing &lt;Enter&gt; or cancel their choices by pressing &lt;Esc&gt;.
--
-- Features: Prompt, UTF8 support, async input, (to be added: secrets, scrolling and wrapping)
--
-- NOTE: you MUST `terminal.initialize()` before calling this widget's `:run()`
-- @classmod cli.Prompt
-- @usage
-- local prompt = Prompt {
--     prompt = "Enter something: ",
--     value = "Hello, 你-好 World 🚀!",
--     max_length = 62,
--     overflow = "wrap" -- or "scroll"   -- TODO: implement
--     -- cancellable = true, -- TODO: implement
--     position = 2,
-- }
-- local result, exitkey = pr:run()

local t = require("terminal")
local utils = require("terminal.utils")
local width = require("terminal.text.width")
local output = require("terminal.output")
local UTF8EditLine = require("terminal.utf8edit")
local utf8 = require("utf8") -- explicitly requires lua-utf8 for Lua < 5.3

-- Key bindings
local keys = t.input.keymap.get_keys()
local keymap = t.input.keymap.get_keymap()

local Prompt = utils.class()

Prompt.keyname2actions = {
  ["ctrl_?"] = "backspace",
  ["left"] = "left",
  ["right"] = "right",
  ["up"] = "up",
  ["down"] = "down",
  ["home"] = "goto_home",
  ["end"] = "goto_end",
  -- emacs keybinding
  ["ctrl_f"] = "left",
  ["ctrl_b"] = "right",
  ["ctrl_a"] = "goto_home",
  ["ctrl_e"] = "goto_end",
  ["ctrl_h"] = "backspace",
  ["ctrl_w"] = "backspace_word",     -- TODO: implement
  ["ctrl_u"] = "backspace_to_start",
  ["ctrl_d"] = "delete",
  ["ctrl_k"] = "delete_to_end",
  ["ctrl_l"] = "clear",
  ["alt_b"] = "left_word",           -- TODO: implement
  ["alt_f"] = "right_word",          -- TODO: implement
  ["alt_d"] = "delete_word",         -- TODO: implement
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
  ["right"] = false,
  ["up"] = false,
  ["down"] = false,
  ["goto_home"] = false,
  ["goto_end"] = false,
})


--- Create a new Prompt instance.
-- @tparam table opts Options for the prompt.
-- @tparam[opt=""] string opts.prompt The prompt text to display.
-- @tparam[opt=""] string opts.value The initial value of the prompt.
-- @tparam[opt=len_char] number opts.position The initial cursor position (in char) of the input
-- @tparam[opt=80] number opts.max_length The maximum length of the input.
-- @treturn Prompt A new Prompt instance.
function Prompt:init(opts)
  self.value = UTF8EditLine(opts.value or "")
  self.prompt = opts.prompt or ""          -- the prompt to display
  self.max_length = opts.max_length or 80  -- the maximum length of the input
  if opts.position then
    local pos = utils.resolve_index(opts.position, self.value:len_char(), 1)
    self.value:goto_home()
    self.value:right(pos - 1)
  end
end



--- Draw the whole thing: prompt and input value.
-- This function writes the prompt and the current input value to the terminal.
-- @return nothing
function Prompt:draw()
  -- hide the cursor
  t.cursor.visible.set(false)
  -- move to the left margin
  t.cursor.position.column(1)
  -- write prompt & value
  output.write(tostring(self.prompt))
  output.write(tostring(self.value))
  output.write(t.clear.eol_seq())
  self:updateCursor()
  -- clear remainder of input size
  output.flush()
end

--- Draw the input value where the prompt ends.
-- This function writes input value to the terminal.
-- @return nothing
function Prompt:drawInput()
  -- hide the cursor
  t.cursor.visible.set(false)
  -- move to end of prompt
  t.cursor.position.column(width.utf8swidth(self.prompt) + 1)
  -- write value
  output.write(tostring(self.value))
  output.write(t.clear.eol_seq())
  self:updateCursor()
  -- clear remainder of input size
  output.flush()
end



-- Update the cursor position.
-- This function moves the cursor to the current position based on the prompt and input value.
-- @tparam number column The column to move the cursor to. If not provided, it defaults to the end of
-- the prompt plus the current input value cursor position.
-- @return nothing
function Prompt:updateCursor(column)
  -- move to cursor position
  t.cursor.position.column(column or width.utf8swidth(self.prompt) + self.value.ocursor)
  -- unhide the cursor
  t.cursor.visible.set(true)
end



-- Read and normalize key input
function Prompt:readKey()
  local key = t.input.readansi(math.huge)
  return key, keymap[key] or key
end



--- Processes key input async
-- This function listens for key events and processes them.
-- @return string "returned" or "cancelled" based on the key pressed.
function Prompt:handleInput()
  -- TODO: this should support "exitKeys"
  while true do
    local key, keyname = self:readKey()
    if keyname then
      -- too hacky maybe?
      local action = Prompt.keyname2actions[keyname]

      if action then
        local redraw = Prompt.actions2redraw[action]
        local handle_action = UTF8EditLine[action]

        if handle_action then
          handle_action(self.value)
        end
        if redraw then
          self:drawInput()
        else
          self:updateCursor()
        end
      elseif keyname == keys.escape and self.cancellable then
        return "cancelled"
      elseif keyname == keys.enter then
        return "returned"
      -- TODO: wait for luasystem's new readansi release
      elseif t.input.keymap.is_printable(key) == false then
        t.bell()
      elseif self.value.ilen >= self.max_length or utf8.len(key) ~= 1 then
        t.bell()
      else -- add the character at the current cursor
        self.value:insert(key)
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
