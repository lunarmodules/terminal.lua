--- TabStrip panel for displaying horizontal tab labels.
--
-- This class creates a single-line panel that displays a horizontal list of tab labels
-- with viewport scrolling and navigation capabilities. TabStrip is responsible only for
-- the strip of labels and navigation between tab-labels.
--
-- A typical implementation would use a panel, vertically split, with the TabStrip in the top panel
-- and the content panels (usually a tab-set panel) in the bottom panel.
-- See `ui.panel.Set`, and the example `tabstrip.lua`.
-- @classmod ui.panel.TabStrip

local Panel = require("terminal.ui.panel.init")
local terminal = require("terminal")
local utils = require("terminal.utils")
local text = require("terminal.text")
local Sequence = require("terminal.sequence")
local width = require("terminal.text.width")
local utf8sub_col = utils.utf8sub_col
local MIN_HEIGHT = 1
local MAX_HEIGHT = 1



local cursor = terminal.cursor
local cursor_pos = cursor.position
local output = terminal.output



local TabStrip = utils.class(Panel)



local default_config = {
  prefix = "[",
  postfix = "]",
  clear_content = false,
  ellipsis = "…",
  padding = 1,
}



-- Local functions



-- Private method to find index of item with given id, or nil.
-- @return number|nil The index of the item with the given id, or nil if not found.
local function index_by_id(self, id)
  for i, item in ipairs(self.items) do
    if item.id == id then
      return i
    end
  end
  return nil
end



-- Validate items
-- Each item must have a label
-- If id is missing, will set index as id
local function validate_items(items)
  items = items or {}
  local processed_items = {}

  for i, item in ipairs(items) do
    if not item.label then
      error("Tab item must have 'label' field, at index(" .. tostring(i) .. ")")
    end

    processed_items[i] = {
      id = item.id or i,
      label = item.label,
    }
  end

  return processed_items
end



-- validate the options when createing a new instance, throw error if invalid
local function validate_option_types(opts)
  if type(opts) ~= "table" then
    error("missing argument: options table isn't given, got " .. type(opts))
  end
  if opts.prefix ~= nil and type(opts.prefix) ~= "string" then
    error("prefix must be a string, got " .. type(opts.prefix))
  end
  if opts.postfix ~= nil and type(opts.postfix) ~= "string" then
    error("postfix must be a string, got " .. type(opts.postfix))
  end
  if opts.padding ~= nil and type(opts.padding) ~= "number" then
    error("padding must be a number, got " .. type(opts.padding))
  end
  if opts.select_cb ~= nil and type(opts.select_cb) ~= "function" then
    error("select_cb must be a function, got " .. type(opts.select_cb))
  end
end



-- Validate selection against items, returns valid selection
-- If selected is not found in items, returns first item id, or nil if no items
-- @tparam table items The array of tab items
-- @tparam any selected The selected tab ID to validate
-- @return any|nil The validated selected tab ID. If not found, 1st entry, or nil if there are no items.
local function selection(items, selected)
  for _, item in ipairs(items) do
    if item.id == selected then
      return selected
    end
  end

  -- not found, pick first item, or nil if no items
  return (items[1] or {}).id
end



--- Create a new TabStrip instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options (see `Panel:init` for inherited properties)
-- @tparam table opts.items Array of tab items, each with `label` field (required) and optional `id` field.
-- @tparam[opt] any opts.selected Initial selected tab id.
-- @tparam[opt="["] string opts.prefix Prefix string for tab labels.
-- @tparam[opt="["] string opts.postfix Postfix string for tab labels.
-- @tparam[opt=1] number opts.padding Number of spaces between tabs.
-- @tparam[opt] table opts.attr Text attributes for the entire strip.
-- @tparam[opt] table opts.selected_attr Text attributes for the selected tab.
-- @tparam[opt] function opts.select_cb Callback function called when selection changes: `TabStrip:select_cb(id)`.
-- @treturn TabStrip A new TabStrip instance.
-- @usage
--   local TabStrip = require("terminal.ui.panel.tab_strip")
--   local tab_strip = TabStrip {
--     items = {
--       { id = "tab1", label = "Tab 1" },
--       { id = "tab2", label = "Tab 2" }
--     },
--     selected = "tab1",
--     attr = { fg = "white", bg = "black" },
--     selected_attr = { reverse = true }
--   }
function TabStrip:init(opts)
  validate_option_types(opts)

  -- TabStrip-specific properties (extract before calling parent)
  local items = validate_items(opts.items)
  local selected = opts.selected
  local prefix = opts.prefix or default_config.prefix
  local postfix = opts.postfix or default_config.postfix
  local padding = opts.padding or default_config.padding
  local attr = opts.attr
  local selected_attr = opts.selected_attr
  local select_cb = opts.select_cb or function() end

  -- Set fixed height of 1 line
  opts.min_height = MIN_HEIGHT
  opts.max_height = MAX_HEIGHT

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw_tabs()
  end

  -- Remove TabStrip-specific options from opts to avoid conflicts with Panel
  opts.items = nil
  opts.selected = nil
  opts.prefix = nil
  opts.postfix = nil
  opts.padding = nil
  opts.attr = nil
  opts.selected_attr = nil
  opts.select_cb = nil

  -- Call parent constructor
  Panel.init(self, opts)
  self.clear_content = default_config.clear_content -- TODO: is this option useful here?

  -- Derive selected_attr from attr if not provided
  if not selected_attr and attr then
    selected_attr = {}
    for k, v in pairs(attr) do
      selected_attr[k] = v
    end

    -- Invert reverse attribute
    selected_attr.reverse = not selected_attr.reverse
  end

  -- Set TabStrip-specific properties after parent constructor
  self.items = items
  self.prefix = prefix
  self.postfix = postfix
  self.padding = padding
  self.attr = attr
  self.selected_attr = selected_attr
  self.select_cb = select_cb
  self.selected = selection(items, selected) -- sets default if selected is invalid

  -- Viewport management state
  self:_invalidate_cache()

  -- Call select_cb during initialization
  self:select_cb(self.selected)
end



-- Private method to draw the tab strip content.
-- @return nothing
function TabStrip:_draw_tabs()
  output.write(
    cursor_pos.backup_seq(),
    cursor_pos.set_seq(self.inner_row, self.inner_col),
    self:_build_tab_line(self.inner_width),
    cursor_pos.restore_seq()
  )
end



-- Private method to invalidate cache.
-- @return nothing
function TabStrip:_invalidate_cache()
  self._cache = nil
end



-- Private method to get (and build) cache of tab widths and positions.
-- @return cache
function TabStrip:_get_cache()
  if not self._cache then
    self._cache = {
      viewport_offset = 0,
    }
    self:_calculate_total_content_width()
  end

  return self._cache
end



-- Private method to calculate total content width.
-- @treturn number Total width of all tabs including padding.
function TabStrip:_calculate_total_content_width()
  local cache = self:_get_cache()
  local total_content_width = 0
  local tab_widths = {}
  cache.tab_widths = tab_widths
  local tab_positions = {}
  cache.tab_positions = tab_positions

  local pre_width = width.utf8swidth(self.prefix)
  local post_width = width.utf8swidth(self.postfix)

  for i, item in ipairs(self.items) do
    -- Format tab: prefix + label + postfix
    local tab_width = pre_width + width.utf8swidth(item.label) + post_width

    tab_widths[i] = tab_width
    tab_positions[i] = total_content_width

    -- Add tab width and padding
    total_content_width = total_content_width + tab_width + self.padding
  end

  -- remove final padding (if there are any tabs)
  if self.items[1] then
    total_content_width = total_content_width - self.padding
  end

  cache.total_content_width = total_content_width
end



-- Private method to calculate effective width and overflow indicators.
-- @tparam number available_width Available width for the tab strip.
-- @treturn boolean has_left_overflow Whether there is overflow to the left.
-- @treturn boolean has_right_overflow Whether there is overflow to the right.
-- @treturn number effective_width The width available for rendering tabs after accounting for overflow indicators.
function TabStrip:_calculate_total_content_width_and_overflow(available_width)
  local has_left_overflow = false
  local has_right_overflow = false
  local effective_width = available_width
  local ellipsis_width = width.utf8swidth(default_config.ellipsis)
  local cache = self:_get_cache()
  local total_content_width = cache.total_content_width

  if cache.total_content_width > available_width then
    -- Need overflow indicators
    effective_width = available_width - (ellipsis_width * 2)
    has_left_overflow = (cache.viewport_offset > 0)
    has_right_overflow = (cache.viewport_offset + effective_width < total_content_width)
  end

  -- Adjust effective width if only one indicator is needed
  if has_left_overflow and not has_right_overflow then
    effective_width = available_width - ellipsis_width
    -- Recalculate has_right_overflow with adjusted effective_width for consistency
    has_right_overflow = (cache.viewport_offset + effective_width < total_content_width)

  elseif has_right_overflow and not has_left_overflow then
    effective_width = available_width - ellipsis_width
    -- Recalculate has_right_overflow with adjusted effective_width for consistency
    has_right_overflow = (cache.viewport_offset + effective_width < total_content_width)
  end

  return has_left_overflow, has_right_overflow, effective_width
end



function TabStrip:adjust_viewport_for_selected()
  if not self.selected then
    return
  end

  local cache = self:_get_cache()

  local selected_index = index_by_id(self, self.selected)
  if not selected_index then
    return
  end

  -- Calculate effective width (accounting for overflow indicators)
  local effective_width = self.inner_width
  local ellipsis_width = width.utf8swidth(default_config.ellipsis)

  if cache.total_content_width > self.inner_width then
    -- Need overflow indicators
    effective_width = self.inner_width - (ellipsis_width * 2)
  end

  -- Get selected tab position and width
  local tab_start = cache.tab_positions[selected_index]
  local tab_width = cache.tab_widths[selected_index]
  local tab_end = tab_start + tab_width

  -- Adjust viewport to show selected tab
  if tab_start < cache.viewport_offset then
    -- Tab is to the left of viewport, move viewport to show it
    cache.viewport_offset = tab_start

  elseif tab_end > cache.viewport_offset + effective_width then
    -- Tab is to the right of viewport, move viewport to show it
    if tab_width > effective_width then
      -- Tab is wider than effective width, left-justify it
      cache.viewport_offset = tab_start

    else
      -- Show tab at the right edge
      cache.viewport_offset = tab_end - effective_width
    end
  end

  -- Clamp viewport offset
  if cache.viewport_offset < 0 then
    cache.viewport_offset = 0
  end
  local max_offset = math.max(0, cache.total_content_width - effective_width)
  if cache.viewport_offset > max_offset then
    cache.viewport_offset = max_offset
  end
end



-- Private method to build the tab line sequence.
-- @tparam number available_width Available width for the tab strip.
-- @treturn Sequence The complete tab line sequence.
function TabStrip:_build_tab_line(available_width)
  local s = Sequence()

  -- Apply global attr if specified
  if self.attr then
    s[#s + 1] = function()
      return text.push_seq(self.attr)
    end
  end

  -- Handle empty items
  if #self.items == 0 then
    s[#s+1] = string.rep(" ", available_width)
    if self.attr then
      s[#s+1] = text.pop_seq
    end
    return s
  end

  -- Adjust viewport to show selected tab
  self:adjust_viewport_for_selected()

  -- Calculate effective width and overflow indicators
  local has_left_overflow, has_right_overflow, effective_width =
    self:_calculate_total_content_width_and_overflow(available_width)
  local ellipsis_width = width.utf8swidth(default_config.ellipsis)

  -- Build output with overflow indicators
  if has_left_overflow then
    s[#s+1] = default_config.ellipsis
  end

  -- Render visible content with attributes
  local rendered_width = self:_render_visible_content(s, effective_width, has_left_overflow)

  if has_right_overflow then
    s[#s+1] = default_config.ellipsis
    rendered_width = rendered_width + ellipsis_width
  end

  -- Fill remaining width with spaces
  local remaining = available_width - rendered_width
  if remaining > 0 then
    s[#s+1] = string.rep(" ", remaining)
  end

  -- Pop global attr if specified
  if self.attr then
    s[#s+1] = text.pop_seq
  end

  return s
end



-- Private method to render the tab line sequence based on current viewport.
-- @tparam Sequence s The sequence to append to.
-- @tparam number effective_width The width available for rendering tabs after accounting for overflow indicators.
-- @tparam boolean has_left_overflow Whether there is overflow to the left (used to determine
-- if we need to start with an ellipsis).
-- @return number The total width of the rendered content (excluding overflow indicators).
function TabStrip:_render_visible_content(s, effective_width, has_left_overflow)
  local ellipsis_width = width.utf8swidth(default_config.ellipsis)
  local rendered_width = has_left_overflow and ellipsis_width or 0
  local cache = self:_get_cache()
  local visible_start = cache.viewport_offset
  local visible_end = visible_start + effective_width

  for i, item in ipairs(self.items) do
    local tab_text = self.prefix .. item.label .. self.postfix
    local tab_start = cache.tab_positions[i]
    local tab_end = tab_start + cache.tab_widths[i]

    -- Check if this tab is visible
    if tab_end > visible_start and tab_start < visible_end then
      local is_selected = (item.id == self.selected)

      -- Calculate what portion of this tab is visible
      local tab_visible_start_col = math.max(0, visible_start - tab_start)
      local tab_visible_end_col = math.min(cache.tab_widths[i], visible_end - tab_start)

      if tab_visible_end_col > tab_visible_start_col then
        -- Extract visible portion of tab
        local visible_tab_text = utf8sub_col(tab_text, tab_visible_start_col + 1, tab_visible_end_col)
        local visible_tab_width = width.utf8swidth(visible_tab_text)

        -- Apply attributes
        if is_selected and self.selected_attr then
          s[#s + 1] = function()
            return text.push_seq(self.selected_attr)
          end
        end
        s[#s+1] = visible_tab_text
        if is_selected and self.selected_attr then
          s[#s+1] = text.pop_seq
        end

        rendered_width = rendered_width + visible_tab_width
      end
    end

    -- Add padding if visible
    if i < #self.items then
      local padding_start = tab_end
      local padding_end = padding_start + self.padding
      if padding_end > visible_start and padding_start < visible_end then
        local padding_visible_start_col = math.max(0, visible_start - padding_start)
        local padding_visible_end_col = math.min(self.padding, visible_end - padding_start)
        if padding_visible_end_col > padding_visible_start_col then
          local padding_width = padding_visible_end_col - padding_visible_start_col
          s[#s + 1] = string.rep(" ", padding_width)
          rendered_width = rendered_width + padding_width
        end
      end
    end

    -- Stop if we've filled the available width
    if rendered_width >= effective_width then
      break
    end
  end
  return rendered_width
end



-- Private method to build the tab line sequence.
-- @tparam number available_width Available width for the tab strip.
-- @treturn Sequence The complete tab line sequence.
function TabStrip:_build_tab_line(available_width)
  local s = Sequence()

  -- Apply global attr if specified
  if self.attr then
    s[#s + 1] = function()
      return text.push_seq(self.attr)
    end
  end

  -- Handle empty items
  if #self.items == 0 then
    s[#s+1] = string.rep(" ", available_width)
    if self.attr then
      s[#s+1] = text.pop_seq
    end
    return s
  end

  -- Build cache
  self:_build_cache()

  -- Adjust viewport to show selected tab
  self:_adjust_viewport_for_selected()

  -- Calculate effective width and overflow indicators
  local has_left_overflow, has_right_overflow, effective_width =
    self:_calculate_total_content_width_and_overflow(available_width)
  local ellipsis_width = width.utf8swidth(default_config.ellipsis)

  -- Build output with overflow indicators
  if has_left_overflow then
    s[#s+1] = default_config.ellipsis
  end

  -- Render visible content with attributes
  local rendered_width = self:_render_visible_content(s, effective_width, has_left_overflow)

  if has_right_overflow then
    s[#s+1] = default_config.ellipsis
    rendered_width = rendered_width + ellipsis_width
  end

  -- Fill remaining width with spaces
  local remaining = available_width - rendered_width
  if remaining > 0 then
    s[#s+1] = string.rep(" ", remaining)
  end

  -- Pop global attr if specified
  if self.attr then
    s[#s+1] = text.pop_seq
  end

  return s
end



--- Get the currently selected tab id.
-- @treturn any|nil The selected tab id, or nil if no tabs exist.
-- @treturn string|nil Error message if no tabs exist.
-- @usage
--   local selected_id, err = tab_strip:get_selected()
--   if err then
--     print("No tabs available")
--   else
--     print("Selected tab:", selected_id)
--   end
function TabStrip:get_selected()
  if not self.selected then
    return nil, "no tabs available"
  end
  return self.selected
end



--- Select a tab by id.
-- @tparam any tab_id The id of the tab to select.
-- @treturn boolean|nil True on success, or nil if id not found.
-- @treturn string|nil Error message if id not found.
-- @usage
--   local success, err = tab_strip:select("tab2")
--   if not success then
--     print("Error:", err)
--   end
function TabStrip:select(tab_id)
  local new_selection = selection(self.items, tab_id)

  if new_selection ~= tab_id then
    return nil, "tab id not found: '" .. tostring(tab_id) .. "'"
  end

  if self.selected == tab_id then
    return true  -- No change, this ID was already selected
  end

  self.selected = tab_id
  self:select_cb(tab_id)

  return true
end



--- Select the next tab.
-- @treturn any|nil The selected tab id, or nil if no tabs exist.
-- @treturn string|nil Error message if no tabs exist.
-- @usage
--   local selected_id, err = tab_strip:select_next()
--   if err then
--     print("Error:", err)
--   end
function TabStrip:select_next()
  if #self.items == 0 then
    return nil, "no tabs available"
  end

  local current_index = index_by_id(self, self.selected)

  -- Increment index, clamp to last tab
  local next_index = math.min(current_index + 1, #self.items)
  local next_id = self.items[next_index].id

  -- Only update and call callback if selection actually changed
  if self.selected ~= next_id then
    self.selected = next_id
    self:select_cb(next_id)
  end

  return self:get_selected()
end



--- Select the previous tab.
-- @treturn any|nil The selected tab id, or nil if no tabs exist.
-- @treturn string|nil Error message if no tabs exist.
-- @usage
--   local selected_id, err = tab_strip:select_prev()
--   if err then
--     print("Error:", err)
--   end
function TabStrip:select_prev()
  if #self.items == 0 then
    return nil, "no tabs available"
  end

  local current_index = index_by_id(self, self.selected)

  -- Decrement index, clamp to first tab
  local prev_index = math.max(current_index - 1, 1)
  local prev_id = self.items[prev_index].id

  -- Only update and call callback if selection actually changed
  if self.selected ~= prev_id then
    self.selected = prev_id
    self:select_cb(prev_id)
  end

  return self.selected
end



--- Get a copy of the items table.
-- @treturn table A copy of the items array.
-- @usage
--   local items = tab_strip:get_items()
function TabStrip:get_items()
  local copy = {}
  for i, item in ipairs(self.items) do
    copy[i] = {
      id = item.id,
      label = item.label,
    }
  end
  return copy
end



--- Set the items table.
-- @tparam table items The new items array.
-- @return nothing
-- @usage
--   tab_strip:set_items({
--     { id = "tab1", label = "Tab 1" },
--     { id = "tab2", label = "Tab 2" }
--   })
function TabStrip:set_items(items)
  -- validate items
  items = validate_items(items)
  self.items = items

  local old_selected = self.selected
  self:_invalidate_cache()
  self.selected = resolve_initial_selection(self.items, old_selected)

  -- Adjust selection: validate it still exists, or default to first
  self.selected = selection(items, self.selected)

  if self.selected ~= old_selected then
    -- selection changed, so call callback
    self:select_cb(self.selected)
  end
end



--- Add a new item to the items list.
-- @tparam table item The item to add (must have `label` field).
-- @tparam[opt] any before_id If provided, insert before the item with this id.
-- @return true
-- @usage
--   tab_strip:add_item({ id = "tab3", label = "Tab 3" })
--   tab_strip:add_item({ id = "tab2.5", label = "Tab 2.5" }, "tab3")
function TabStrip:add_item(item, before_id)
  -- Validate item has required label field
  if not item.label then
    error("Tab item must have 'label' field")
  end

  -- Process item with default id if missing
  local new_item = {
    id = item.id or (#self.items + 1),
    label = item.label,
  }

  if before_id then
    local insert_index = index_by_id(self, before_id)
    if insert_index then
      table.insert(self.items, insert_index, new_item)
    else
      -- If before_id not found, append to end
      table.insert(self.items, new_item)
    end
  else
    -- Append to end
    table.insert(self.items, new_item)
  end

  self:_invalidate_cache()
  return true
end



--- Remove an item from the items list.
-- @tparam any id The id of the item to remove.
-- @treturn boolean|nil True on success, or nil if id not found.
-- @treturn string|nil Error message if id not found.
-- @usage
--   local success, err = tab_strip:remove_item("tab2")
function TabStrip:remove_item(id)
  local remove_index = index_by_id(self, id)
  if not remove_index then
    return nil, "tab id not found"
  end

  local was_selected = (self.selected == id)

  table.remove(self.items, remove_index)
  self:_invalidate_cache()

  if not was_selected then
    return true  -- No change to selection, so we're done
  end

  -- selected tab was removed, need to update selection
  if #self.items == 0 then
    -- No tabs left, clear selection
    self.selected = nil

  elseif remove_index == 1 then
    -- First tab removed, move to new first tab
    self.selected = self.items[1].id

  else
    -- Move selection one to the left
    self.selected = self.items[remove_index - 1].id
  end

  self:select_cb(self.selected)

  return true
end



return TabStrip
