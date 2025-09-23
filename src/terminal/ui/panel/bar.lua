--- Panel bar for single-line terminal UI elements.
--
-- This class creates a fixed-height panel (1 line) that displays content in a
-- structured format with left, center, and right sections separated by configurable
-- spacing. The bar uses margin and padding parameters to control spacing, and supports
-- text attributes for styling individual sections or the entire bar.
--
-- The line format is: [margin][left][padding][center][padding][right][margin]
-- where padding is distributed to fill the available space, and content can be
-- truncated using different strategies (left, right, or drop).
--
-- @classmod ui.panel.Bar

local Panel = require("terminal.ui.panel.init")
local terminal = require("terminal")
local utils = require("terminal.utils")
local text = require("terminal.text")
local draw = require("terminal.draw")
local Sequence = require("terminal.sequence")

local Bar = utils.class(Panel)


--- Create a new Bar instance.
-- @tparam table opts Options for the bar.
-- @tparam[opt=1] number opts.margin Number of spaces from left and right edges.
-- @tparam[opt=2] number opts.padding Minimum number of spaces between each section.
-- @tparam[opt] table opts.left Left section configuration.
-- @tparam[opt] string opts.left.text Left section content.
-- @tparam[opt="right"] string opts.left.type Truncation type for left section ("left", "right", or "drop").
-- @tparam[opt] table opts.left.attr Text attributes for left section content.
-- @tparam[opt] table opts.center Center section configuration.
-- @tparam[opt] string opts.center.text Center section content.
-- @tparam[opt="right"] string opts.center.type Truncation type for center section ("left", "right", or "drop").
-- @tparam[opt] table opts.center.attr Text attributes for center section content.
-- @tparam[opt] table opts.right Right section configuration.
-- @tparam[opt] string opts.right.text Right section content.
-- @tparam[opt="right"] string opts.right.type Truncation type for right section ("left", "right", or "drop").
-- @tparam[opt] table opts.right.attr Text attributes for right section content.
-- @tparam[opt] table opts.attr Text attributes for the entire bar.
-- @tparam[opt] string opts.name Optional name for the bar. Defaults to tostring(self) if not provided.
-- @treturn Bar A new Bar instance.
-- @usage
--   local Bar = require("terminal.ui.panel.bar")
--   local bar = Bar {
--     margin = 1,
--     padding = 2,
--     left = {
--       text = "File",
--       type = "right",
--       attr = { fg = "blue" }
--     },
--     center = {
--       text = "Editor",
--       type = "left",
--       attr = { fg = "yellow", brightness = "bright" }
--     },
--     right = {
--       text = "Help",
--       type = "drop",
--       attr = { fg = "green" }
--     },
--     attr = { bg = "black" }
--   }
function Bar:init(opts)
  opts = opts or {}

  -- Set fixed height of 1 line
  opts.min_height = 1
  opts.max_height = 1

  -- Bar-specific properties (extract before calling parent)
  local margin = opts.margin or 1
  local padding = opts.padding or 2
  local left_config = opts.left or {}
  local center_config = opts.center or {}
  local right_config = opts.right or {}
  local attr = opts.attr

  -- Extract component configurations
  local left = left_config.text or ""
  local left_type = left_config.type or "right"
  local left_attr = left_config.attr
  local center = center_config.text or ""
  local center_type = center_config.type or "right"
  local center_attr = center_config.attr
  local right = right_config.text or ""
  local right_type = right_config.type or "right"
  local right_attr = right_config.attr

  -- Remove bar-specific options from opts to avoid conflicts with Panel
  opts.margin = nil
  opts.padding = nil
  opts.left = nil
  opts.center = nil
  opts.right = nil
  opts.attr = nil

  -- Provide content callback for parent constructor
  opts.content = function(self, row, col, height, width)
    self:_draw_bar(row, col, height, width)
  end

  -- Call parent constructor
  Panel.init(self, opts)

  -- Set bar-specific properties after parent constructor
  self.margin = margin
  self.padding = padding
  self.left_type = left_type
  self.left_attr = left_attr
  self.center_type = center_type
  self.center_attr = center_attr
  self.right_type = right_type
  self.right_attr = right_attr
  self.attr = attr
  self:set_left(left)
  self:set_center(center)
  self:set_right(right)
end

-- Private method to draw the bar content.
-- @tparam number row Starting row position.
-- @tparam number col Starting column position.
-- @tparam number height Panel height (should be 1).
-- @tparam number width Panel width.
-- @return nothing
function Bar:_draw_bar(row, col, height, width)
  local line = self:_build_bar_line(width)

  terminal.cursor.position.set(row, col)
  terminal.output.write(line)
end

-- Private method to build the bar line sequence.
-- @tparam number width Available width for the bar.
-- @treturn Sequence The complete bar line sequence.
function Bar:_build_bar_line(width)
  -- Calculate available space for content (excluding margins and padding)
  local margin_space = self.margin * 2
  local min_padding_space = self.padding * 2
  local available_content_space = width - margin_space - min_padding_space

  if available_content_space < 0 then
    return Sequence(string.rep(" ", math.max(0, width)))
  end

  -- Distribute available space among left, center, right
  local left_alloc = math.floor(available_content_space * 0.3)
  local center_alloc = math.floor(available_content_space * 0.4)
  local right_alloc = available_content_space - left_alloc - center_alloc

  -- Use title_fmt for proper truncation
  local left_str, left_w = draw.line.title_fmt(left_alloc, self.left, self.left_type)
  local center_str, center_w = draw.line.title_fmt(center_alloc, self.center, self.center_type)
  local right_str, right_w = draw.line.title_fmt(right_alloc, self.right, self.right_type)

  -- Calculate actual space used by content
  local content_width = left_w + center_w + right_w
  local total_used = margin_space + content_width + min_padding_space
  local extra_space = width - total_used

  -- Distribute extra space between the two padding areas
  local left_center_extra = math.floor(extra_space / 2)
  local center_right_extra = extra_space - left_center_extra  -- Use remaining space to avoid rounding errors

  -- Build the line with proper spacing using Sequence
  local left_center_padding = self.padding + left_center_extra
  local center_right_padding = self.padding + center_right_extra

  local s = Sequence()
  if self.attr then
    s[#s+1] = function() return text.stack.push_seq(self.attr) end
  end
  s[#s+1] = string.rep(" ", self.margin)
  if self.left_attr then
    s[#s+1] = function() return text.stack.push_seq(self.left_attr) end
    s[#s+1] = left_str
    s[#s+1] = text.stack.pop_seq
  else
    s[#s+1] = left_str
  end
  s[#s+1] = string.rep(" ", left_center_padding)
  if self.center_attr then
    s[#s+1] = function() return text.stack.push_seq(self.center_attr) end
    s[#s+1] = center_str
    s[#s+1] = text.stack.pop_seq
  else
    s[#s+1] = center_str
  end
  s[#s+1] = string.rep(" ", center_right_padding)
  if self.right_attr then
    s[#s+1] = function() return text.stack.push_seq(self.right_attr) end
    s[#s+1] = right_str
    s[#s+1] = text.stack.pop_seq
  else
    s[#s+1] = right_str
  end
  s[#s+1] = terminal.clear.eol_seq
  if self.attr then
    s[#s+1] = text.stack.pop_seq
  end
  return s
end

--- Set the left section content.
-- @tparam string content The left section content.
-- @return nothing
function Bar:set_left(content)
  self.left = content or ""
end

--- Set the center section content.
-- @tparam string content The center section content.
-- @return nothing
function Bar:set_center(content)
  self.center = content or ""
end

--- Set the right section content.
-- @tparam string content The right section content.
-- @return nothing
function Bar:set_right(content)
  self.right = content or ""
end


return Bar
