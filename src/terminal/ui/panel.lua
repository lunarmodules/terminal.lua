--- Panel system for terminal UI layouts.
--
-- This module provides a flexible panel system for creating terminal UI layouts.
-- Each panel can contain content or be divided into two child panels (horizontally or vertically).
-- Panels automatically recalculate their size and position based on parent constraints.
--
-- Features:
-- - Automatic layout calculation with size constraints
-- - Horizontal and vertical panel division
-- - Content callback system for rendering
-- - Minimum and maximum size constraints
-- - Dynamic resizing based on orientation
--
-- *Usage:*
--   local Panel = require("terminal.ui.panel")
--
--   -- Create a root panel with content
--   local root = Panel {
--     content = function(row, col, height, width)
--       -- render content here
--     end
--   }
--
--   -- Create a divided panel
--   local divided = Panel {
--     orientation = Panel.orientations.horizontal, -- or Panel.orientations.vertical
--     children = {
--       Panel { content = function(r, c, h, w) -- left/top panel
--         -- render left/top content
--       end },
--       Panel { content = function(r, c, h, w) -- right/bottom panel
--         -- render right/bottom content
--       end }
--     }
--   }
--
--   -- Calculate layout
--   root:calculate_layout(1, 1, 24, 80) -- row, col, height, width
--   root:render()
--
-- @classmod terminal.ui.panel

local terminal = require("terminal")
local cursor = require("terminal.cursor")
local utils = require("terminal.utils")
local draw = require("terminal.draw")

-- TODO: specify on panel a border and title to draw
-- TODO: implement a way to specify a background color for the panel
local Panel = utils.class()

-- Panel orientations
local orientations = utils.make_lookup("orientation", {
  horizontal = "HORIZONTAL",
  vertical = "VERTICAL",
})
Panel.orientations = orientations

-- Default size constraints
local DEFAULT_MIN_SIZE = 1
local DEFAULT_MAX_SIZE = math.huge

--- Create a new Panel instance.
-- @tparam table opts Options for the panel.
-- @tparam[opt] function opts.content Content callback function that takes (row, col, height, width) parameters.
-- @tparam[opt] table opts.orientation Panel orientation: Panel.orientations.horizontal or Panel.orientations.vertical (for divided panels).
-- @tparam[opt] table opts.children Array of exactly 2 child panels (for divided panels).
-- @tparam[opt=1] number opts.min_height Minimum height constraint (content panels only).
-- @tparam[opt=1] number opts.min_width Minimum width constraint (content panels only).
-- @tparam[opt=math.huge] number opts.max_height Maximum height constraint (content panels only).
-- @tparam[opt=math.huge] number opts.max_width Maximum width constraint (content panels only).
-- @tparam[opt=0.5] number opts.split_ratio Ratio for dividing child panels (0.0 to 1.0).
-- @treturn Panel A new Panel instance.
function Panel:init(opts)
  opts = opts or {}

  -- Validate that either content or children is provided, but not both
  local has_content = opts.content ~= nil
  local has_children = opts.children ~= nil and #opts.children > 0

  assert(has_content or has_children, "Panel must have either content callback or children")
  assert(not (has_content and has_children), "Panel cannot have both content and children")

  -- Content panel
  if has_content then
    self.content = opts.content
    self.orientation = nil
    self.children = nil
  else
    -- Divided panel
    assert(#opts.children == 2, "Divided panel must have exactly 2 children")
    -- Validate orientation by checking if it's one of the valid values
    assert(opts.orientation == Panel.orientations.horizontal or opts.orientation == Panel.orientations.vertical,
           "Invalid orientation: " .. tostring(opts.orientation) .. ". Must be Panel.orientations.horizontal or Panel.orientations.vertical")

    self.content = nil
    self.orientation = opts.orientation
    self.children = opts.children
    self.split_ratio = opts.split_ratio or 0.5
    assert(self.split_ratio >= 0.0 and self.split_ratio <= 1.0, "Split ratio must be between 0.0 and 1.0")
  end

  -- Size constraints (private)
  if has_content then
    -- Leaf panels can have explicit constraints
    self._min_height = opts.min_height or DEFAULT_MIN_SIZE
    self._min_width = opts.min_width or DEFAULT_MIN_SIZE
    self._max_height = opts.max_height or DEFAULT_MAX_SIZE
    self._max_width = opts.max_width or DEFAULT_MAX_SIZE
  else
    -- Split panels derive constraints from children (will be calculated)
    self._min_height = nil
    self._min_width = nil
    self._max_height = nil
    self._max_width = nil
  end

  -- Calculated layout properties (set by calculate_layout)
  self.row = nil
  self.col = nil
  self.height = nil
  self.width = nil
end

--- Calculate the layout for this panel and all its children.
-- @tparam number parent_row Parent panel's starting row.
-- @tparam number parent_col Parent panel's starting column.
-- @tparam number parent_height Parent panel's height.
-- @tparam number parent_width Parent panel's width.
-- @return nothing
function Panel:calculate_layout(parent_row, parent_col, parent_height, parent_width)
  -- Set position
  self.row = parent_row
  self.col = parent_col

  -- Calculate size based on constraints
  local calculated_height = parent_height
  local calculated_width = parent_width

  -- For split panels, derive constraints from children first
  if self.children then
    self:_derive_constraints_from_children()
  end

  -- Apply size constraints
  if self._min_height then
    calculated_height = math.max(self._min_height, math.min(self._max_height, calculated_height))
  end
  if self._min_width then
    calculated_width = math.max(self._min_width, math.min(self._max_width, calculated_width))
  end

  self.height = calculated_height
  self.width = calculated_width

  -- If this is a divided panel, calculate children layouts
  if self.children then
    self:_calculate_children_layout()
  end
end

--- Derive size constraints from children (internal method).
-- @return nothing
function Panel:_derive_constraints_from_children()
  local child1, child2 = self.children[1], self.children[2]

  if self.orientation == Panel.orientations.horizontal then
    -- For horizontal division, derive width constraints from children
    self._min_width = (child1._min_width or DEFAULT_MIN_SIZE) + (child2._min_width or DEFAULT_MIN_SIZE)
    self._max_width = (child1._max_width or DEFAULT_MAX_SIZE) + (child2._max_width or DEFAULT_MAX_SIZE)

    -- Height constraints are the minimum of both children
    self._min_height = math.max(child1._min_height or DEFAULT_MIN_SIZE, child2._min_height or DEFAULT_MIN_SIZE)
    self._max_height = math.min(child1._max_height or DEFAULT_MAX_SIZE, child2._max_height or DEFAULT_MAX_SIZE)
  else -- VERTICAL
    -- For vertical division, derive height constraints from children
    self._min_height = (child1._min_height or DEFAULT_MIN_SIZE) + (child2._min_height or DEFAULT_MIN_SIZE)
    self._max_height = (child1._max_height or DEFAULT_MAX_SIZE) + (child2._max_height or DEFAULT_MAX_SIZE)

    -- Width constraints are the minimum of both children
    self._min_width = math.max(child1._min_width or DEFAULT_MIN_SIZE, child2._min_width or DEFAULT_MIN_SIZE)
    self._max_width = math.min(child1._max_width or DEFAULT_MAX_SIZE, child2._max_width or DEFAULT_MAX_SIZE)
  end
end

--- Calculate layout for child panels (internal method).
-- @return nothing
function Panel:_calculate_children_layout()
  local child1, child2 = self.children[1], self.children[2]

  if self.orientation == Panel.orientations.horizontal then
    -- Horizontal division: split width
    local child1_width = math.floor(self.width * self.split_ratio)
    local child2_width = self.width - child1_width

    -- Ensure minimum widths
    local child1_min_width = child1._min_width or DEFAULT_MIN_SIZE
    local child2_min_width = child2._min_width or DEFAULT_MIN_SIZE

    if child1_width < child1_min_width then
      child1_width = child1_min_width
      child2_width = self.width - child1_width
    end
    if child2_width < child2_min_width then
      child2_width = child2_min_width
      child1_width = self.width - child2_width
    end

    -- Calculate child layouts
    child1:calculate_layout(self.row, self.col, self.height, child1_width)
    child2:calculate_layout(self.row, self.col + child1_width, self.height, child2_width)

  else -- VERTICAL
    -- Vertical division: split height
    local child1_height = math.floor(self.height * self.split_ratio)
    local child2_height = self.height - child1_height

    -- Ensure minimum heights
    local child1_min_height = child1._min_height or DEFAULT_MIN_SIZE
    local child2_min_height = child2._min_height or DEFAULT_MIN_SIZE

    if child1_height < child1_min_height then
      child1_height = child1_min_height
      child2_height = self.height - child1_height
    end
    if child2_height < child2_min_height then
      child2_height = child2_min_height
      child1_height = self.height - child2_height
    end

    -- Calculate child layouts
    child1:calculate_layout(self.row, self.col, child1_height, self.width)
    child2:calculate_layout(self.row + child1_height, self.col, child2_height, self.width)
  end
end

--- Set the height or width of this content panel.
-- @tparam number size The new size to set.
-- @return nothing
function Panel:set_size(size)
  assert(self.content ~= nil, "set_size can only be called on content panels")

  -- For content panels, we can set both width and height constraints
  self._min_width = size
  self._max_width = size
  self._min_height = size
  self._max_height = size
end

--- Get the current size of this panel.
-- @treturn number,number The current width and height.
function Panel:get_size()
  return self.width, self.height
end

--- Set the split ratio for divided panels.
-- @tparam number ratio The split ratio (0.0 to 1.0).
-- @return nothing
function Panel:set_split_ratio(ratio)
  assert(self.children ~= nil, "Split ratio can only be set on divided panels")
  assert(ratio >= 0.0 and ratio <= 1.0, "Split ratio must be between 0.0 and 1.0")
  self.split_ratio = ratio
end

--- Render this panel and all its children.
-- @return nothing
function Panel:render()
  if self.content then
    -- Render content panel
    self.content(self.row, self.col, self.height, self.width)
  else
    -- Render child panels
    for _, child in ipairs(self.children) do
      child:render()
    end
  end
end

--- Get the layout information for this panel.
-- @treturn table Layout information with fields `row`, `col`, `height`, `width`.
function Panel:get_layout()
  return {
    row = self.row,
    col = self.col,
    height = self.height,
    width = self.width
  }
end

--- Check if this panel has content (is a leaf panel).
-- @treturn boolean True if this panel has content, false if it has children.
function Panel:has_content()
  return self.content ~= nil
end

--- Check if this panel is divided (has children).
-- @treturn boolean True if this panel has children, false if it has content.
function Panel:is_divided()
  return self.children ~= nil
end

--- Get the orientation of this panel.
-- @treturn table|nil The orientation (Panel.orientations.horizontal or Panel.orientations.vertical) or nil if not divided.
function Panel:get_orientation()
  return self.orientation
end

--- Get the children of this panel.
-- @treturn table|nil Array of child panels or nil if not divided.
function Panel:get_children()
  return self.children
end

--- Get the split ratio of this panel.
-- @treturn number|nil The split ratio or nil if not divided.
function Panel:get_split_ratio()
  return self.split_ratio
end

--- Get the minimum height constraint of this panel.
-- @treturn number The minimum height.
function Panel:get_min_height()
  return self._min_height
end

--- Get the minimum width constraint of this panel.
-- @treturn number The minimum width.
function Panel:get_min_width()
  return self._min_width
end

--- Get the maximum height constraint of this panel.
-- @treturn number The maximum height.
function Panel:get_max_height()
  return self._max_height
end

--- Get the maximum width constraint of this panel.
-- @treturn number The maximum width.
function Panel:get_max_width()
  return self._max_width
end

--- Update size constraints for this panel.
-- @tparam table constraints Table with min_height, min_width, max_height, max_width keys.
-- @return nothing
function Panel:update_constraints(constraints)
  if constraints.min_height then
    self._min_height = constraints.min_height
  end
  if constraints.min_width then
    self._min_width = constraints.min_width
  end
  if constraints.max_height then
    self._max_height = constraints.max_height
  end
  if constraints.max_width then
    self._max_width = constraints.max_width
  end
end

--- Find a panel by a predicate function.
-- @tparam function predicate Function that takes a panel and returns true if it matches.
-- @treturn Panel|nil The first matching panel or nil if not found.
function Panel:find_panel(predicate)
  if predicate(self) then
    return self
  end

  if self.children then
    for _, child in ipairs(self.children) do
      local found = child:find_panel(predicate)
      if found then
        return found
      end
    end
  end

  return nil
end

--- Get all leaf panels (panels with content) in this panel tree.
-- @treturn table Array of all leaf panels.
function Panel:get_leaf_panels()
  local leaves = {}

  if self:has_content() then
    table.insert(leaves, self)
  else
    for _, child in ipairs(self.children) do
      local child_leaves = child:get_leaf_panels()
      for _, leaf in ipairs(child_leaves) do
        table.insert(leaves, leaf)
      end
    end
  end

  return leaves
end


--- Returns a new content callback that draws a border and optional title around your panel content.
-- This function wraps your original content callback, first drawing a box (border and title) using the given
-- box format and title, then calling your callback with the coordinates and size *inside* the border.
--
-- The border is drawn using the specified box format (see `terminal.draw.box_fmt`). If any of the
-- box format's top, bottom, left, or right characters are empty strings, that side of the border is omitted
-- and the space becomes part of the *inner* area.
--
-- The wrapped callback receives adjusted (row, col, height, width) arguments, so your content is always
-- drawn inside the border area.
--
-- @tparam function callback The original content callback to wrap.
-- @tparam table format The box format table (see `terminal.draw.box_fmt`).
-- @tparam[opt] string title Optional title to display in the border.
-- @treturn function A new callback that draws the border and then calls your original callback.
function Panel.content_border(callback, format, title)
  assert(type(callback) == "function", "callback must be a function (do not use colon notation)")

  return function(row, col, height, width)
    local lastcol = col + width - 1
    local _, c = terminal.size()
    local lastcolumn = (lastcol >= c)

    cursor.position.backup()
    cursor.position.set(row, col)
    draw.box(height, width, format, true, title, lastcolumn)
    cursor.position.restore()

    if format.t ~= "" then
      row = row + 1
      height = height - 1
    end

    if format.l ~= "" then
      col = col + 1
      width = width - 1
    end

    if format.r ~= "" then
      width = width - 1
    end

    if format.b ~= "" then
      height = height - 1
    end

    callback(row, col, height, width)
  end
end

return Panel
