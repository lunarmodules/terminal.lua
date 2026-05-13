--- A progress bar class.
-- A configurable horizontal progress bar that renders to a Sequence.
-- The bar displays fixed elements (label, caps, format string, status) around a fill area,
-- and the total output fills exactly the requested width in display columns.
-- @classmod progress.Bar

local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")
local text = require("terminal.text")
local tw = require("terminal.text.width")



local Bar = utils.class()



--- Predefined tip-character sets for sub-character precision at the bar tip.
-- @table Bar.tip_chars
-- @field block Array of 7 Unicode block elements for smooth fill progression
Bar.tip_chars = {
  block = {"▏", "▎", "▍", "▌", "▋", "▊", "▉"},
}



--- Create a new Bar instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options
-- @tparam[opt="█"] string opts.filled_char Character for fully-filled cells
-- @tparam[opt=" "] string opts.empty_char Character for empty cells
-- @tparam[opt] table opts.tip_chars Array of tip characters for sub-char precision (1-indexed, ascending fill)
-- @tparam[opt=""] string opts.left_cap Left bracket/delimiter
-- @tparam[opt=""] string opts.right_cap Right bracket/delimiter
-- @tparam[opt=0] number opts.min Minimum value (lower bound)
-- @tparam[opt=100] number opts.max Maximum value (upper bound)
-- @tparam[opt] number opts.value Initial value (defaults to opts.min)
-- @tparam[opt=false] boolean opts.reverse When true, inverts progress (shows remaining instead)
-- @tparam[opt=""] string opts.label Text printed before left cap
-- @tparam[opt] string opts.format Format string for progress value (e.g. "%d%%" for "45%"), or nil to omit
-- @tparam[opt=""] string opts.status Text printed after format string (e.g. "downloading", "complete")
-- @tparam[opt] textattr opts.attr Text attributes wrapping entire output
-- @tparam[opt] textattr opts.cap_attr Text attributes for left and right caps
-- @tparam[opt] textattr opts.filled_attr Text attributes for filled + tip portion
-- @tparam[opt] textattr opts.empty_attr Text attributes for empty portion
-- @tparam[opt] textattr opts.label_attr Text attributes for label
-- @tparam[opt] textattr opts.status_attr Text attributes for format string + status
-- @treturn Bar A new Bar instance
-- @usage
-- local Bar = require("terminal.progress.bar")
--
-- local bar = Bar {
--   filled_char = "█", empty_char = " ",
--   tip_chars = Bar.tip_chars.block,
--   left_cap = "[", right_cap = "]",
--   format = "%d%%",
--   status = "downloading",
-- }
function Bar:init(opts)
  opts = opts or {}

  if opts.tip_chars ~= nil then
    if type(opts.tip_chars) ~= "table" or #opts.tip_chars == 0 then
      error("tip_chars must be a non-empty array if provided", 2)
    end
  end

  if opts.min ~= nil and type(opts.min) ~= "number" then
    error("min must be a number if provided", 2)
  end

  if opts.max ~= nil and type(opts.max) ~= "number" then
    error("max must be a number if provided", 2)
  end

  if (opts.min or 0) >= (opts.max or 100) then
    error(("min (%d) must be less than max (%d)"):format(opts.min or 0, opts.max or 100), 2)
  end

  if opts.value ~= nil and type(opts.value) ~= "number" then
    error("value must be a number if provided", 2)
  end

  self.filled_char = opts.filled_char or "█"
  self.empty_char = opts.empty_char or " "
  self.tip_chars = opts.tip_chars
  self.left_cap = opts.left_cap or ""
  self.right_cap = opts.right_cap or ""
  self.min = opts.min or 0
  self.max = opts.max or 100
  self.value = opts.value or self.min
  self.reverse = not not opts.reverse
  self.label = opts.label or ""
  self.format = opts.format
  self.status = opts.status or ""
  self.attr = opts.attr
  self.cap_attr = opts.cap_attr
  self.filled_attr = opts.filled_attr
  self.empty_attr = opts.empty_attr
  self.label_attr = opts.label_attr
  self.status_attr = opts.status_attr
end



--- Set the progress value, clamping to [min, max].
-- @tparam number value The new progress value
-- @return nothing
function Bar:set(value)
end



--- Set the status text.
-- @tparam string status The new status text (e.g. "waiting", "downloading", "unpacking", "complete")
-- @return nothing
function Bar:set_status(status)
end



--- Render just the bar fill area.
-- Renders the fill, tip, and empty portions based on current value.
-- Does not include reverse logic, which is handled by render().
-- Subclasses can override this to customize bar rendering.
-- @tparam number width Width available for the bar fill area (in display columns)
-- @treturn Sequence The rendered bar fill
function Bar:render_bar(width)
  width = math.max(0, width)

  local fraction = (self.value - self.min) / (self.max - self.min)
  local fill = fraction * width
  local full_cells = math.floor(fill)
  local tip_chars = self.tip_chars
  local tip_index = tip_chars and math.floor((fill - full_cells) * #tip_chars) or 0

  local s = Sequence()

  if self.filled_attr then
    s[#s + 1] = function()
      return text.push_seq(self.filled_attr)
    end
  end

  s[#s + 1] = string.rep(self.filled_char, full_cells)

  if tip_index > 0 then
    s[#s + 1] = tip_chars[tip_index]
  end

  if self.filled_attr then
    s[#s + 1] = text.pop_seq
  end

  local empty_cells = width - full_cells - (tip_index > 0 and 1 or 0)

  if self.empty_attr then
    s[#s + 1] = function()
      return text.push_seq(self.empty_attr)
    end
  end

  s[#s + 1] = string.rep(self.empty_char, empty_cells)

  if self.empty_attr then
    s[#s + 1] = text.pop_seq
  end

  return s
end



--- Render the progress bar to a Sequence.
-- The bar fills exactly `width` display columns, with fixed elements (label, caps, format, status)
-- measured first and the fill area taking the remainder.
-- @tparam number width Total output width in display columns
-- @treturn Sequence The rendered bar
-- @treturn number The width passed in (echoed back)
-- @treturn number Always 1 (bar height is fixed at one line, sub-classes can override)
function Bar:render(width)
end



return Bar
