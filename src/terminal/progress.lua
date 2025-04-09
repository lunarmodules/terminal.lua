--- A module for progress updating.
-- @module terminal.progress

local M = {}
package.loaded["terminal.progress"] = M -- Register the module early to avoid circular dependencies

local t = require("terminal")
local tw = require("terminal.text.width")
local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")
local gettime = require("system").gettime

--- table with predefined sprites for progress spinners.
-- The sprites are tables of strings, where each string is a frame in the spinner animation.
-- The frame at index 0 is optional and is the "done" message, the rest are the animation frames.
--
-- Available pre-defined spinners are:
-- * `bar_vertical` - a vertical bar that grows from the bottom to the top
-- * `bar_horizontal` - a horizontal bar that grows from left to right
-- * `square_rotate` - a square that rotates clockwise
-- * `moon` - a moon that waxes and wanes
-- * `dot_expanding` - a dot that expands and contracts
-- * `dot_vertical` - a dot that moves up and down
-- * `dot1_snake` - a dot that moves in a snake-like pattern
-- * `dot2_snake` - 2 dots that move in a snake-like pattern
-- * `dot3_snake` - 3 dots that move in a snake-like pattern
-- * `dot4_snake` - 4 dots that move in a snake-like pattern
-- * `block_pulsing` - a block that pulses in transparency
-- * `bar_rotating` - a bar that rotates clockwise
-- * `spinner` - a spinner that rotates clockwise
-- * `dot_horizontal` - 3 dots growing from left to right
M.sprites = utils.make_lookup("spinner-sprite", {
  bar_vertical = { [0] = " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁", " " },
  bar_horizontal = { [0] = " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█", "▉", "▊", "▋", "▌", "▍", "▎", "▏", " " },
  square_rotate = { [0] = " ", "▖", "▘", "▝", "▗" },
  moon = { [0] = " ", "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘" },
  dot_expanding = { [0] = " ", ".", "o", "O", "o" },
  dot_vertical = { [0] = " ", "⢀", "⠠", "⠐", "⠈", "⠐", "⠠" },
  dot1_snake = { [0] = " ", "⠁", "⠈", "⠐", "⠠", "⢀", "⡀", "⠄", "⠂" },
  dot2_snake = { [0] = " ", "⠃", "⠉", "⠘", "⠰", "⢠", "⣀", "⡄", "⠆" },
  dot3_snake = { [0] = " ", "⡆", "⠇", "⠋", "⠙", "⠸", "⢰", "⣠", "⣄" },
  dot4_snake = { [0] = " ", "⡇", "⠏", "⠛", "⠹", "⢸", "⣰", "⣤", "⣆"},
  block_pulsing = { [0] = " ", " ", "░", "▒", "▓", "█", "▓", "▒", "░" },
  bar_rotating = { [0] = " ", "┤", "┘", "┴", "└", "├", "┌", "┬", "┐" },
  spinner = { [0] = " ", "|", "/", "-", "\\" },
  dot_horizontal = { [0] = "   ", "   ", ".  ", ".. ", "..." },
})

-- Class definition for ProgressSpinner
local ProgressSpinner = {}
ProgressSpinner.__index = ProgressSpinner

--- Creates a new ProgressSpinner instance.
-- @tparam table opts Configuration options:
-- @tparam table opts.sprites A table of animation frames (index 1..n) and optionally a [0] "done" frame.
-- @tparam[opt=0.2] number opts.stepsize Time in seconds between updates.
-- @tparam table opts.textattr Text styling applied to the spinner.
-- @tparam table opts.done_textattr Styling applied to the done sprite.
-- @tparam string opts.done_sprite Overrides [0] sprite.
-- @tparam number opts.row Row position (if provided, col must be too).
-- @tparam number opts.col Column position.
-- @usage
-- local spinner = ProgressSpinner:new{ sprites = ProgressSpinner.sprites.spinner }
-- while running do spinner:step_once() end
-- spinner:step_once(true)
function ProgressSpinner:new(opts)
  assert(opts and opts.sprites and #opts.sprites > 0, "sprites must be provided")

  local self = setmetatable({}, ProgressSpinner)
  self.sprites = opts.sprites
  self.stepsize = opts.stepsize or 0.2
  self.textattr = opts.textattr
  self.done_textattr = opts.done_textattr
  self.done_sprite = opts.done_sprite
  self.row = opts.row
  self.col = opts.col
  self.step = 0
  self.next_step = gettime()

  assert((not self.row and not self.col) or (self.row and self.col),
    "both row and col must be provided, or neither")

  self.steps = {}
  local setpos = (self.row and t.cursor.position.set_seq(self.row, self.col)) or ""
  local savepos = (self.row and t.cursor.position.backup_seq()) or ""
  local restorepos = (self.row and t.cursor.position.restore_seq()) or ""

  local attr_push = self.textattr and function() return t.text.stack.push_seq(self.textattr) end
  local attr_pop = self.textattr and t.text.stack.pop_seq or nil

  local attr_push_done = self.done_textattr and function() return t.text.stack.push_seq(self.done_textattr) end or attr_push

  for i = 0, #self.sprites do
    local sprite = self.sprites[i] or ""
    if i == 0 and self.done_sprite then sprite = self.done_sprite end
    local s = Sequence()
    s[#s+1] = savepos
    s[#s+1] = setpos
    s[#s+1] = (i == 0 and attr_push_done) or attr_push
    s[#s+1] = sprite .. t.cursor.position.left_seq(tw.utf8swidth(sprite))
    s[#s+1] = attr_pop
    s[#s+1] = restorepos
    self.steps[i] = s
  end

  return self
end

--- Updates the spinner animation or renders the final "done" sprite.
-- @tparam[opt=false] boolean done If true, renders the done sprite.
function ProgressSpinner:step_once(done)
  if gettime() >= self.next_step or done then
    if done then
      self.step = 0
    else
      self.next_step = gettime() + self.stepsize
      self.step = self.step + 1
      if self.step > #self.sprites then self.step = 1 end
    end
    t.output.write(self.steps[self.step])
  end
end

return {
  ProgressSpinner = ProgressSpinner,
  sprites = M.sprites,
}
