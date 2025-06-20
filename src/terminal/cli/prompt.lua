--- Prompt input for CLI tools.
--
-- This module provides a simple way to read line input from the terminal.
-- Features: Prompt, UTF8 support, async input, (to be added: secrets, scrolling and wrapping)
-- The user can confirm their choices by pressing <Enter>
-- Cancel their choices by pressing <Esc>
-- NOTE: you MUST `terminal.initialize()` before calling this widget's `:run()`
-- @classmod cli.Prompt
-- @usage
-- local prompt = Prompt {
--     prompt = "Enter something: ",
--     value = "Hello, 你-好 World 🚀!",
--     max_length = 62,
--     overflow = "wrap" -- or "scroll"
--     position = 2,
--     fsleep = sys.sleep,
-- }
-- local result, exitkey = pr:run()

local t = require("terminal")
local sys = require("system")
local utils = require("terminal.utils")
local width = require("terminal.text.width")
local output = require("terminal.output")
local UTF8EditLine = require("terminal.text.utf8edit").UTF8EditLine
local utf8 = require("utf8") -- explicitly requires lua-utf8 for Lua < 5.3

-- Key bindings
local keys = t.input.keymap.get_keys()
local keymap = t.input.keymap.get_keymap()

local Prompt = utils.class()

Prompt.keyname2actions = {
  ["ctrl_?"] = "backspace",
  ["ctrl_h"] = "backspace",
  ["left"] = "left",
  ["right"] = "right",
  ["up"] = "up",
  ["down"] = "down",
  -- emacs keybinding
  ["ctrl_f"] = "left",
  ["ctrl_b"] = "right",
  ["ctrl_a"] = "home",
  ["ctrl_e"] = "end",
  ["ctrl_w"] = "backspace_word",
  ["ctrl_u"] = "backspace_to_start",
  ["ctrl_d"] = "delete_word",
  ["ctrl_k"] = "delete_to_end",
  ["ctrl_l"] = "clear",
}

Prompt.actions2redraw = utils.make_lookup("actions", {
  ["backspace"] = true,
  ["delete"] = true,
  ["backsapce_word"] = true,
  ["backsapce_to_start"] = true,
  ["delete_word"] = true,
  ["delete_to_end"] = true,
  ["clear"] = true,
  --
  ["left"] = false,
  ["right"] = false,
  ["home"] = false,
  ["up"] = false,
  ["down"] = false,
  ["end"] = false,
})

function Prompt:init(opts)
  self.value = UTF8EditLine(opts.value or "")
  self.prompt = opts.prompt or ""        -- the prompt to display
  self.max_length = opts.max_length      -- the maximum length of the input
  self.drawn_before = false              -- if the prompt has been drawn
  self.fsleep = opts.fsleep or sys.sleep -- the sleep function to use
end

function Prompt:draw(redraw)
  if redraw or not self.prompt_ready then
    -- we are at start of prompt
    self.prompt_ready = true
    t.cursor.position.column(1)
    output.write(tostring(self.prompt))
  else
    -- we are at current cursor position, move to start of prompt
    t.cursor.position.column(width.utf8swidth(self.prompt) + 1)
  end
  -- write prompt & value
  local value = tostring(self.value)
  output.write(value)
  output.write(t.clear.eol_seq())
  -- clear remainder of input size
  output.flush()
end

function Prompt:updateCursor(column)
  -- move to cursor position
  t.cursor.position.column(column or width.utf8swidth(self.prompt) + self.value.ocursor)
end

-- Read and normalize key input
function Prompt:readKey()
  local key = t.input.readansi(math.huge, self.fsleep)
  return key, keymap[key] or key
end

--- Processes key input async
-- This function listens for key events and processes them.
-- If an exit key is pressed, it yields the input value and the exit key.
-- @tparam string key The key that was pressed.
-- @tparam string keytype The type of the key (e.g., "ansi", "control").
function Prompt:handleInput()
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
          self:draw(false)
        end
        self:updateCursor()
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
        self.value:add(key)
        self:draw(false)
        self:updateCursor()
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
