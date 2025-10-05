--- Panel system for terminal UI layouts.
--
-- This module provides a flexible panel system for creating terminal UI layouts.
-- Each panel can contain content or be divided into two child panels (horizontally or vertically).
-- Panels automatically recalculate their size and position based on parent constraints.
--
-- Features:
--
-- - Automatic layout calculation with size constraints
-- - Horizontal and vertical panel division
-- - Content callback system for rendering
-- - Minimum and maximum size constraints
-- - Dynamic resizing based on orientation
--
-- The typical usage starts with a `ui.panel.Screen` instance as the root panel.
--
-- *Usage:*
--
--     local Panel = require("terminal.ui.panel")
--
--     -- Create a root panel with content
--     local root = Panel {
--       content = function(row, col, height, width)
--         -- render content here
--       end
--     }
--
--     -- Create a divided panel
--     local divided = Panel {
--       orientation = Panel.orientations.horizontal, -- or Panel.orientations.vertical
--       children = {
--         Panel { content = function(self, r, c, h, w) -- left/top panel
--           -- render left/top content
--         end },
--         Panel { content = function(self, r, c, h, w) -- right/bottom panel
--           -- render right/bottom content
--         end }
--       }
--     }
--
--     -- Calculate layout
--     root:calculate_layout(1, 1, 24, 80) -- row, col, height, width
--     root:render()
--
-- @classmod ui.Panel

local terminal = require("terminal")
local cursor = require("terminal.cursor")
local utils = require("terminal.utils")
local draw = require("terminal.draw")
local text = require("terminal.text")

local Panel = utils.class()

--- Panel orientation constants table.
-- @field ui.panel.orientations table lookup table for child panels by name.
Panel.orientations = utils.make_lookup("orientation", {
  horizontal = "horizontal",
  vertical = "vertical",
})

-- Default size constraints
local DEFAULT_MIN_SIZE = 1
local DEFAULT_MAX_SIZE = math.huge

--- Create a new Panel instance.
-- Do not call this method directly, call on the class instead. See example.
-- @tparam table opts Options for the panel.
-- @tparam[opt] function opts.content Content callback function that takes (self, row, col, height, width) parameters.
-- @tparam[opt=true] boolean opts.clear_content Whether to clear the content area before rendering.
-- @tparam[opt] table opts.orientation Panel orientation: `Panel.orientations.horizontal` or `Panel.orientations.vertical` (for divided panels).
-- @tparam[opt] table opts.children Array of exactly 2 child panels (for divided panels).
-- @tparam[opt] string opts.name Optional name for the panel. Defaults to tostring(self) if not provided.
-- @tparam[opt=1] number opts.min_height Minimum height constraint (content panels only).
-- @tparam[opt=1] number opts.min_width Minimum width constraint (content panels only).
-- @tparam[opt=math.huge] number opts.max_height Maximum height constraint (content panels only).
-- @tparam[opt=math.huge] number opts.max_width Maximum width constraint (content panels only).
-- @tparam[opt=0.5] number opts.split_ratio Ratio for dividing child panels (0.0 to 1.0).
-- @tparam[opt] table opts.border Border configuration for content panels, with the following properties:
-- @tparam table border.format The box format table (see `terminal.draw.box_fmt`).
-- @tparam[opt] table border.attr Table of attributes for the border, eg. `{ fg = "red", bg = "blue" }`.
-- @tparam[opt] string border.title Optional title to display in the border.
-- @tparam[opt="right"] string border.truncation_type The type of title-truncation to apply, either "left", "right", or "drop".
-- @tparam[opt] table border.title_attr Table of attributes for the title, eg. `{ fg = "red", bg = "blue" }`.
-- @treturn Panel A new Panel instance.
-- @usage
--   local Panel = require("terminal.ui.panel")
--   local panel = Panel {
--     content = function(self, row, col, height, width)
--       -- render content here
--     end,
--     border = {
--       format = terminal.draw.box_fmt.single,
--       title = "My Panel"
--     }
--   }
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
    self.clear_content = opts.clear_content ~= false
    self.orientation = nil
    self.children = nil

    -- Border configuration for content panels
    self.border = opts.border
    if self.border then
      assert(type(self.border) == "table", "border must be a table")
      assert(self.border.format, "border.format is required when border is specified")
    end
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

  -- Panel name
  self.name = opts.name or tostring(self)

  --- Panels lookup table.
  -- Provides access to child panels by name with recursive search and caching.
  -- @field ui.panel.panels table lookup table for child panels by name.
  -- @usage
  --   local header = main_panel.panels.header -- Returns panel named "header"
  --   local not_found = parent.panels.nonexistent -- Returns nil
  self.panels = setmetatable({}, {
    __index = function(panels, name)
      panels[name] = self:get_panel(name)
      return rawget(panels, name)
    end
  })

  -- Calculated layout properties (set by calculate_layout)
  self.row = nil
  self.col = nil
  self.height = nil
  self.width = nil
  self.inner_row = nil
  self.inner_col = nil
  self.inner_height = nil
  self.inner_width = nil
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

  -- Calculate inner content area (accounting for border)
  self:_calculate_inner_area()

  -- If this is a divided panel, calculate children layouts
  if self.children then
    self:_calculate_children_layout()
  end
end


-- Private method to calculate inner content area coordinates.
-- @return nothing
function Panel:_calculate_inner_area()
  local row, col, height, width = self.row, self.col, self.height, self.width

  if self.border then
    local format = self.border.format

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
  end

  self.inner_row = row
  self.inner_col = col
  self.inner_height = height
  self.inner_width = width
end


-- Derive size constraints from children (internal method).
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

-- Calculate layout for child panels (internal method).
-- @return nothing
function Panel:_calculate_children_layout()
  local child1, child2 = self.children[1], self.children[2]

  if self.orientation == Panel.orientations.horizontal then
    -- Horizontal division: split width
    local child1_width = math.floor(self.width * self.split_ratio)
    local child2_width = self.width - child1_width

    -- Get size constraints
    local child1_min_width = child1._min_width or DEFAULT_MIN_SIZE
    local child1_max_width = child1._max_width
    local child2_min_width = child2._min_width or DEFAULT_MIN_SIZE
    local child2_max_width = child2._max_width

    -- Apply maximum width constraints
    if child1_max_width and child1_width > child1_max_width then
      child1_width = child1_max_width
      child2_width = self.width - child1_width
    end
    if child2_max_width and child2_width > child2_max_width then
      child2_width = child2_max_width
      child1_width = self.width - child2_width
    end

    -- Ensure minimum widths
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

    -- Get size constraints
    local child1_min_height = child1._min_height or DEFAULT_MIN_SIZE
    local child1_max_height = child1._max_height
    local child2_min_height = child2._min_height or DEFAULT_MIN_SIZE
    local child2_max_height = child2._max_height

    -- Apply maximum height constraints
    if child1_max_height and child1_height > child1_max_height then
      child1_height = child1_max_height
      child2_height = self.height - child1_height
    end
    if child2_max_height and child2_height > child2_max_height then
      child2_height = child2_max_height
      child1_height = self.height - child2_height
    end

    -- Ensure minimum heights
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


--- Get the current size of this panel.
-- @treturn number The current height in rows.
-- @treturn number The current width in columns.
function Panel:get_size()
  return self.height, self.width
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
    -- Render content panel with optional border
    self:draw_border()
    if self.clear_content then
      self:clear()
    end
    self:content(self.inner_row, self.inner_col, self.inner_height, self.inner_width)
  else
    -- Render child panels
    for _, child in ipairs(self.children) do
      child:render()
    end
  end
end


--- Get the type of this panel.
-- @return Returns "content" for content panels, or the orientation (Panel.orientations.horizontal or Panel.orientations.vertical) for divided panels.
function Panel:get_type()
  return self.orientation or "content"
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



--- Find a panel by name in this panel tree.
-- Searches in order: self, child 1, child 2.
-- @tparam string name The name to search for.
-- @treturn Panel|nil The first panel found with the given name, or nil if not found.
function Panel:get_panel(name)
  -- Check self first
  if self.name == name then
    return self
  end

  -- If this is a divided panel, check children
  if self.children then
    for _, child in ipairs(self.children) do
      local found = child:get_panel(name)
      if found then
        return found
      end
    end
  end

  return nil
end


--- Clears the panel content (inner area).
-- @return nothing
function Panel:clear()
  cursor.position.backup()
  terminal.cursor.position.set(self.inner_row, self.inner_col)
  terminal.clear.box(self.inner_height, self.inner_width)
  cursor.position.restore()
end



--- Draw the border around panel content.
-- @return nothing
function Panel:draw_border()
  if not self.border then
    return
  end

  local row, col, height, width = self.row, self.col, self.height, self.width

  local format = self.border.format
  local attr = self.border.attr
  local title = self.border.title
  local truncation_type = self.border.truncation_type or "right"
  local title_attr = self.border.title_attr

  local lastcol = col + width - 1
  local _, c = terminal.size()
  local lastcolumn = (lastcol >= c)

  cursor.position.backup()
  cursor.position.set(row, col)
  if attr then
    text.stack.push(attr)
  end
  draw.box(height, width, format, false, title, lastcolumn, truncation_type, title_attr)
  if attr then
    text.stack.pop()
  end
  cursor.position.restore()
end


return Panel
