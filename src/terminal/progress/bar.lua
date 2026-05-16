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
-- @table Bar.block_tip_chars
-- @field block Array of 9 Unicode block elements for smooth fill progression
Bar.block_tip_chars = {
  block = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"},
}


--- Fill-mode constants for the `mode` constructor option.
-- @table Bar.modes
-- @field clamp Value is clamped to [min, max] (default)
-- @field loop Value wraps back to min after exceeding max
-- @field bounce Value oscillates: fills left-to-right then right-to-left
Bar.modes = utils.make_lookup("bar mode", {
  clamp  = "clamp",
  loop   = "loop",
  bounce = "bounce",
})


-- TODO: add a "rolling" mode as an option where the bar fills up to a point, then jumps back
-- to empty and starts again, for use as a spinner (e.g. for unknown-duration tasks).
-- This would mean not clamping to max, and allowing value to wrap around to min after exceeding max.
-- We'd also not show the % complete in this format.

--- Create a new Bar instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options
-- @tparam[opt="█"] string opts.filled_char Character for fully-filled cells
-- @tparam[opt=" "] string opts.empty_char Character for empty cells
-- @tparam[opt] table opts.tip_chars Array of tip characters for sub-char precision (1-indexed, ascending fill)
-- The tip is always shown! so the range should start with `empty` and end with `filled`.
-- @tparam[opt=" "] string opts.pad_char Single-width character used to pad the bar to the requested
-- width when the fill does not cover the full area; pass `""` to omit padding entirely
-- @tparam[opt=" "] string opts.left_cap Left bracket/delimiter
-- @tparam[opt=" "] string opts.right_cap Right bracket/delimiter
-- @tparam[opt=0] number opts.min Minimum value (lower bound)
-- @tparam[opt=100] number opts.max Maximum value (upper bound)
-- @tparam[opt] number opts.value Initial value (defaults to opts.min)
-- @tparam[opt="clamp"] string opts.mode Fill mode: `"clamp"` stops at max, `"loop"` wraps back to min, `"bounce"` oscillates. See `Bar.modes`.
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

  local _ = Bar.modes[opts.mode or Bar.modes.clamp]  -- errors with friendly message on unknown value

  if opts.pad_char ~= nil then
    if type(opts.pad_char) ~= "string" or
       (opts.pad_char ~= "" and tw.utf8swidth(opts.pad_char) ~= 1) then
      error("pad_char must be a single-width character or an empty string if provided", 2)
    end
  end

  self.filled_char = opts.filled_char or "█"
  self.empty_char = opts.empty_char or " "
  self.tip_chars = opts.tip_chars
  self.left_cap = opts.left_cap or " "
  self.right_cap = opts.right_cap or " "
  self.min = opts.min or 0
  self.max = opts.max or 100
  self.value = opts.value or self.min
  self.mode = opts.mode or Bar.modes.clamp
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
  self.pad_char = opts.pad_char or " "
end



--- Set the progress value.
-- @tparam number value The new progress value
-- @return nothing
function Bar:set(value)
  if type(value) ~= "number" then
    error("value must be a number", 2)
  end
  self.value = value
end



--- Get the progress value.
-- @treturn number The current progress value
function Bar:get()
  return self.value
end



--- Set the status text.
-- @tparam string status The new status text (e.g. "waiting", "downloading", "unpacking", "complete")
-- @return nothing
function Bar:set_status(status)
  self.status = status or ""
end



--- Render just the bar fill area.
-- Renders the fill, tip, and empty portions based on current value.
-- Subclasses can override this to customize bar rendering.
-- @tparam number fraction Progress as a fraction between 0 and 1
-- @tparam number width Width available for the bar fill area (in display columns)
-- @treturn Sequence The rendered bar fill
-- @treturn number Actual bar width in display columns (equals `width` unless `pad_char=""` and padding was needed)
function Bar:render_bar(fraction, width)
  local filled_char_width = tw.utf8cwidth(self.filled_char)
  local empty_char_width = tw.utf8cwidth(self.empty_char)
  local tip_char_width = self.tip_chars and tw.utf8swidth(self.tip_chars[1]) or 0 -- assume all tips are equal width
  if tip_char_width > width then
    -- if the tip char doesn't fit, we can't show anything
    local s = Sequence()
    if width > 0 and self.pad_char ~= "" then
      s[#s + 1] = string.rep(self.pad_char, width)
    end
    return s, (self.pad_char ~= "" and width or 0)
  end

  local columns_empty
  local columns_filled = fraction * (width - tip_char_width)  -- fractional !!

  local tip_char = ""
  if self.tip_chars then
    if fraction >= 1 then
      tip_char = self.tip_chars[#self.tip_chars]
    else
      local tip_index = (columns_filled - math.floor(columns_filled)) * #self.tip_chars
      tip_index = math.floor(tip_index) + 1
      tip_char = self.tip_chars[tip_index]
    end
  end

  -- start with the filled columns, left-over is empty
  columns_filled = math.floor(columns_filled)  -- no more fractional
  local filled_count = math.floor(columns_filled / filled_char_width)
  columns_empty = width - tip_char_width - filled_count * filled_char_width

  if empty_char_width == 2 and filled_char_width == 1 then
    -- if columns_empty is uneven, width char_width 2, then we need to adjust
    -- to prevent unnecessary padding of the last column
    if columns_empty % 2 == 1 and columns_filled > 1 then
      columns_empty = columns_empty + 1
      columns_filled = columns_filled - 1
      filled_count = math.floor(columns_filled / filled_char_width)
    end
  end

  local empty_count = math.floor(columns_empty / empty_char_width)
  local padding_width = width - (filled_count * filled_char_width) - (empty_count * empty_char_width) - tip_char_width

  -- build the sequence
  local s = Sequence()

  if self.filled_attr then
    s[#s + 1] = function()
      return text.push_seq(self.filled_attr)
    end
  end

  s[#s + 1] = string.rep(self.filled_char, filled_count)

  s[#s + 1] = tip_char

  if self.filled_attr then
    s[#s + 1] = text.pop_seq
  end

  if self.empty_attr then
    s[#s + 1] = function()
      return text.push_seq(self.empty_attr)
    end
  end

  s[#s + 1] = string.rep(self.empty_char, empty_count)

  local actual_width = width

  if padding_width > 0 then
    if self.pad_char ~= "" then
      s[#s + 1] = self.pad_char
    else
      -- if pad_char is empty, we just eat the extra space and report a smaller actual width
      actual_width = width - padding_width
    end
  end

  if self.empty_attr then
    s[#s + 1] = text.pop_seq
  end

  return s, actual_width
end



--- Render the progress bar to a Sequence.
-- The bar fills exactly `width` display columns, with fixed elements (label, caps, format, status)
-- measured first and the fill area taking the remainder.
-- @tparam number width Total output width in display columns
-- @treturn Sequence The rendered bar
-- @treturn number The width passed in (sub-classes can override)
-- @treturn number Always 1 (bar height is fixed at one line, sub-classes can override)
function Bar:render(width)
  width = math.max(0, width)

  local display_value = self.value
  local reverse = self.reverse

  if self.mode == Bar.modes.clamp then
    display_value = math.max(self.min, math.min(self.max, display_value))

  elseif self.mode == Bar.modes.loop then
    local range = self.max - self.min
    display_value = ((display_value - self.min) % range) + self.min

  elseif self.mode == Bar.modes.bounce then
    local range = self.max - self.min
    local double_range = range * 2
    local mod = (display_value - self.min) % double_range
    if mod > range then
      display_value = self.max - (mod - range)
    else
      display_value = self.min + mod
    end
  end

  local fraction = (display_value - self.min) / (self.max - self.min)
  if reverse then
    fraction = 1 - fraction
  end

  local format_str = self.format and string.format(self.format, self.value) or ""
  local fixed_w = tw.utf8swidth(self.label)
    + tw.utf8swidth(self.left_cap)
    + tw.utf8swidth(self.right_cap)
    + tw.utf8swidth(format_str)
    + tw.utf8swidth(self.status)
  local fill_w = math.max(0, width - fixed_w)

  local bar_seq = self:render_bar(fraction, fill_w)

  local s = Sequence()

  if self.attr then
    s[#s+1] = function() return text.push_seq(self.attr) end
  end

  if self.label_attr then
    s[#s+1] = function() return text.push_seq(self.label_attr) end
  end
  s[#s+1] = self.label
  if self.label_attr then
    s[#s+1] = text.pop_seq
  end

  if self.cap_attr and self.left_cap ~= "" then
    s[#s+1] = function() return text.push_seq(self.cap_attr) end
  end
  s[#s+1] = self.left_cap
  if self.cap_attr and self.left_cap ~= "" then
    s[#s+1] = text.pop_seq
  end

  s[#s+1] = bar_seq

  if self.cap_attr and self.right_cap ~= "" then
    s[#s+1] = function() return text.push_seq(self.cap_attr) end
  end
  s[#s+1] = self.right_cap
  if self.cap_attr and self.right_cap ~= "" then
    s[#s+1] = text.pop_seq
  end

  if self.status_attr then
    s[#s+1] = function() return text.push_seq(self.status_attr) end
  end
  s[#s+1] = format_str
  s[#s+1] = self.status
  if self.status_attr then
    s[#s+1] = text.pop_seq
  end

  if self.attr then
    s[#s+1] = text.pop_seq
  end

  return s, width, 1
end



return Bar
