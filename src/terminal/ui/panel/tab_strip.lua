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

local TabStrip = utils.class(Panel)


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
-- @tparam[opt] function opts.select_cb Callback function called when selection changes: `select_cb(self, id)`.
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
  opts = opts or {}

  -- Set fixed height of 1 line
  opts.min_height = 1
  opts.max_height = 1

  -- TabStrip-specific properties (extract before calling parent)
  local items = opts.items
  local selected = opts.selected
  local prefix = opts.prefix
  local postfix = opts.postfix
  local padding = opts.padding
  local attr = opts.attr
  local selected_attr = opts.selected_attr
  local select_cb = opts.select_cb

  -- Remove TabStrip-specific options from opts to avoid conflicts with Panel
  opts.items = nil
  opts.selected = nil
  opts.prefix = nil
  opts.postfix = nil
  opts.padding = nil
  opts.attr = nil
  opts.selected_attr = nil
  opts.select_cb = nil

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw_tabs()
  end

  -- Call parent constructor
  Panel.init(self, opts)
  self.clear_content = false

  -- Process and validate items
  local processed_items = {}
  if items then
    for i, item in ipairs(items) do
      -- Validate item has required label field
      assert(item.label, "Tab item must have 'label' field")

      -- Create processed item with default id if missing
      local processed_item = {
        id = item.id or i,
        label = item.label
      }
      table.insert(processed_items, processed_item)
    end
  end

  -- Validate option types
  if prefix ~= nil and type(prefix) ~= "string" then
    error("prefix must be a string, got " .. type(prefix))
  end
  if postfix ~= nil and type(postfix) ~= "string" then
    error("postfix must be a string, got " .. type(postfix))
  end
  if padding ~= nil and type(padding) ~= "number" then
    error("padding must be a number, got " .. type(padding))
  end
  if select_cb ~= nil and type(select_cb) ~= "function" then
    error("select_cb must be a function, got " .. type(select_cb))
  end

  -- Apply defaults for configuration parameters
  prefix = prefix or "["
  postfix = postfix or "]"
  padding = padding or 1

  -- Derive selected_attr from attr if not provided
  if not selected_attr and attr then
    selected_attr = {}
    for k, v in pairs(attr) do
      selected_attr[k] = v
    end
    -- Invert reverse attribute
    if attr.reverse ~= nil then
      selected_attr.reverse = not attr.reverse
    else
      selected_attr.reverse = true
    end
  end

  -- Set TabStrip-specific properties after parent constructor
  self.items = processed_items
  self.prefix = prefix
  self.postfix = postfix
  self.padding = padding
  self.attr = attr
  self.selected_attr = selected_attr
  self.select_cb = select_cb

  -- Viewport management state
  self._viewport_offset = 0
  self._cache_valid = false
  self._tab_widths = {}
  self._tab_positions = {}
  self._total_content_width = 0

  -- Handle initial selection
  if #processed_items == 0 then
    self.selected = nil
  elseif selected then
    -- Validate selected id exists in items
    local found = false
    for _, item in ipairs(processed_items) do
      if item.id == selected then
        found = true
        break
      end
    end
    if found then
      self.selected = selected
    else
      -- Default to first tab if selected id not found
      self.selected = processed_items[1].id
    end
  else
    -- Default to first tab (index 1)
    self.selected = processed_items[1].id
  end

  -- Call select_cb during initialization if provided
  if self.select_cb then
    self.select_cb(self, self.selected)
  end
end


-- Private method to draw the tab strip content.
-- @return nothing
function TabStrip:_draw_tabs()
  terminal.output.write(
    terminal.cursor.position.backup_seq(),
    terminal.cursor.position.set_seq(self.inner_row, self.inner_col),
    self:_build_tab_line(self.inner_width),
    terminal.cursor.position.restore_seq()
  )
end


-- Private method to invalidate cache.
-- @return nothing
function TabStrip:_invalidate_cache()
  self._cache_valid = false
end

-- Private method to build cache of tab widths and positions.
-- @return nothing
function TabStrip:_build_cache()
  if self._cache_valid then
    return
  end

  self._tab_widths = {}
  self._tab_positions = {}
  self._total_content_width = 0

  for i, item in ipairs(self.items) do
    -- Format tab: prefix + label + postfix
    local tab_text = self.prefix .. item.label .. self.postfix
    local tab_width = width.utf8swidth(tab_text)

    self._tab_widths[i] = tab_width
    self._tab_positions[i] = self._total_content_width

    -- Add tab width
    self._total_content_width = self._total_content_width + tab_width

    -- Add padding (except after last tab)
    if i < #self.items then
      self._total_content_width = self._total_content_width + self.padding
    end
  end

  self._cache_valid = true
end

-- Private method to adjust viewport to show selected tab.
-- @return nothing
function TabStrip:_adjust_viewport_for_selected()
  if #self.items == 0 or not self.selected then
    return
  end

  self:_build_cache()

  -- Find selected tab index
  local selected_index = nil
  for i, item in ipairs(self.items) do
    if item.id == self.selected then
      selected_index = i
      break
    end
  end

  if not selected_index then
    return
  end

  -- Get default ellipsis width
  local ellipsis = "…"
  local ellipsis_width = width.utf8swidth(ellipsis)

  -- Calculate effective width (accounting for overflow indicators)
  local effective_width = self.inner_width

  if self._total_content_width > self.inner_width then
    -- Need overflow indicators
    effective_width = self.inner_width - (ellipsis_width * 2)
  end

  -- Get selected tab position and width
  local tab_start = self._tab_positions[selected_index]
  local tab_width = self._tab_widths[selected_index]
  local tab_end = tab_start + tab_width

  -- Adjust viewport to show selected tab
  if tab_start < self._viewport_offset then
    -- Tab is to the left of viewport, move viewport to show it
    self._viewport_offset = tab_start
  elseif tab_end > self._viewport_offset + effective_width then
    -- Tab is to the right of viewport, move viewport to show it
    if tab_width > effective_width then
      -- Tab is wider than effective width, left-justify it
      self._viewport_offset = tab_start
    else
      -- Show tab at the right edge
      self._viewport_offset = tab_end - effective_width
    end
  end

  -- Clamp viewport offset
  if self._viewport_offset < 0 then
    self._viewport_offset = 0
  end
  local max_offset = math.max(0, self._total_content_width - effective_width)
  if self._viewport_offset > max_offset then
    self._viewport_offset = max_offset
  end
end

-- Private method to build the tab line sequence.
-- @tparam number available_width Available width for the tab strip.
-- @treturn Sequence The complete tab line sequence.
function TabStrip:_build_tab_line(available_width)
  local s = Sequence()

  -- Apply global attr if specified
  if self.attr then
    s[#s+1] = function() return text.stack.push_seq(self.attr) end
  end

  -- Handle empty items
  if #self.items == 0 then
    s[#s+1] = string.rep(" ", available_width)
    if self.attr then
      s[#s+1] = text.stack.pop_seq
    end
    return s
  end

  -- Build cache
  self:_build_cache()

  -- Adjust viewport to show selected tab
  self:_adjust_viewport_for_selected()

  -- Get default ellipsis
  local ellipsis = "…"
  local ellipsis_width = width.utf8swidth(ellipsis)

  -- Calculate effective width and overflow indicators
  local has_left_overflow = false
  local has_right_overflow = false
  local effective_width = available_width

  if self._total_content_width > available_width then
    -- Need overflow indicators
    effective_width = available_width - (ellipsis_width * 2)
    has_left_overflow = (self._viewport_offset > 0)
    has_right_overflow = (self._viewport_offset + effective_width < self._total_content_width)
  end

  -- Adjust effective width if only one indicator is needed
  if has_left_overflow and not has_right_overflow then
    effective_width = available_width - ellipsis_width
    -- Recalculate has_right_overflow with adjusted effective_width for consistency
    has_right_overflow = (self._viewport_offset + effective_width < self._total_content_width)
  elseif has_right_overflow and not has_left_overflow then
    effective_width = available_width - ellipsis_width
    -- Recalculate has_right_overflow with adjusted effective_width for consistency
    has_right_overflow = (self._viewport_offset + effective_width < self._total_content_width)
  end

  -- Build output with overflow indicators
  if has_left_overflow then
    s[#s+1] = ellipsis
  end

  -- Render visible content with attributes
  local visible_start = self._viewport_offset
  local visible_end = visible_start + effective_width
  local rendered_width = has_left_overflow and ellipsis_width or 0

  for i, item in ipairs(self.items) do
    local tab_text = self.prefix .. item.label .. self.postfix
    local tab_start = self._tab_positions[i]
    local tab_end = tab_start + self._tab_widths[i]

    -- Check if this tab is visible
    if tab_end > visible_start and tab_start < visible_end then
      local is_selected = (item.id == self.selected)

      -- Calculate what portion of this tab is visible
      local tab_visible_start_col = math.max(0, visible_start - tab_start)
      local tab_visible_end_col = math.min(self._tab_widths[i], visible_end - tab_start)

      if tab_visible_end_col > tab_visible_start_col then
        -- Extract visible portion of tab
        local visible_tab_text = utf8sub_col(tab_text, tab_visible_start_col + 1, tab_visible_end_col)
        local visible_tab_width = width.utf8swidth(visible_tab_text)

        -- Apply attributes
        if is_selected and self.selected_attr then
          s[#s+1] = function() return text.stack.push_seq(self.selected_attr) end
        end
        s[#s+1] = visible_tab_text
        if is_selected and self.selected_attr then
          s[#s+1] = text.stack.pop_seq
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
          s[#s+1] = string.rep(" ", padding_width)
          rendered_width = rendered_width + padding_width
        end
      end
    end

    -- Stop if we've filled the available width
    if rendered_width >= effective_width then
      break
    end
  end

  if has_right_overflow then
    s[#s+1] = ellipsis
    rendered_width = rendered_width + ellipsis_width
  end

  -- Fill remaining width with spaces
  local remaining = available_width - rendered_width
  if remaining > 0 then
    s[#s+1] = string.rep(" ", remaining)
  end

  -- Pop global attr if specified
  if self.attr then
    s[#s+1] = text.stack.pop_seq
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
  if #self.items == 0 then
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
  if #self.items == 0 then
    return nil, "no tabs available"
  end

  -- Find the tab with the given id
  local found = false
  for _, item in ipairs(self.items) do
    if item.id == tab_id then
      found = true
      break
    end
  end

  if not found then
    return nil, "tab id not found"
  end

  -- Only update and call callback if selection actually changed
  if self.selected ~= tab_id then
    self.selected = tab_id
    if self.select_cb then
      self.select_cb(self, tab_id)
    end
  end

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
    return self:get_selected()
  end

  -- Find current index
  local current_index = nil
  for i, item in ipairs(self.items) do
    if item.id == self.selected then
      current_index = i
      break
    end
  end

  -- If current_index is nil, something went wrong, default to first
  if not current_index then
    current_index = 1
  end

  -- Increment index, clamp to last tab
  local next_index = math.min(current_index + 1, #self.items)
  local next_id = self.items[next_index].id

  -- Only update and call callback if selection actually changed
  if self.selected ~= next_id then
    self.selected = next_id
    if self.select_cb then
      self.select_cb(self, next_id)
    end
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
    return self:get_selected()
  end

  -- Find current index
  local current_index = nil
  for i, item in ipairs(self.items) do
    if item.id == self.selected then
      current_index = i
      break
    end
  end

  -- If current_index is nil, something went wrong, default to first
  if not current_index then
    current_index = 1
  end

  -- Decrement index, clamp to first tab
  local prev_index = math.max(current_index - 1, 1)
  local prev_id = self.items[prev_index].id

  -- Only update and call callback if selection actually changed
  if self.selected ~= prev_id then
    self.selected = prev_id
    if self.select_cb then
      self.select_cb(self, prev_id)
    end
  end

  return self:get_selected()
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
      label = item.label
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
  -- Process and validate items
  local processed_items = {}
  if items then
    for i, item in ipairs(items) do
      -- Validate item has required label field
      assert(item.label, "Tab item must have 'label' field")

      -- Create processed item with default id if missing
      local processed_item = {
        id = item.id or i,
        label = item.label
      }
      table.insert(processed_items, processed_item)
    end
  end

  self.items = processed_items
  self:_invalidate_cache()

  -- Adjust selection: validate it still exists, or default to first
  if #processed_items == 0 then
    self.selected = nil
  else
    local found = false
    for _, item in ipairs(processed_items) do
      if item.id == self.selected then
        found = true
        break
      end
    end
    if not found then
      self.selected = processed_items[1].id
    end
  end
end


--- Add a new item to the items list.
-- @tparam table item The item to add (must have `label` field).
-- @tparam[opt] any before_id If provided, insert before the item with this id.
-- @return nothing
-- @usage
--   tab_strip:add_item({ id = "tab3", label = "Tab 3" })
--   tab_strip:add_item({ id = "tab2.5", label = "Tab 2.5" }, "tab3")
function TabStrip:add_item(item, before_id)
  -- Validate item has required label field
  assert(item.label, "Tab item must have 'label' field")

  -- Process item with default id if missing
  local processed_item = {
    id = item.id or (#self.items + 1),
    label = item.label
  }

  if before_id then
    -- Find the index of the item with before_id
    local insert_index = nil
    for i, existing_item in ipairs(self.items) do
      if existing_item.id == before_id then
        insert_index = i
        break
      end
    end

    if insert_index then
      table.insert(self.items, insert_index, processed_item)
    else
      -- If before_id not found, append to end
      table.insert(self.items, processed_item)
    end
  else
    -- Append to end
    table.insert(self.items, processed_item)
  end

  self:_invalidate_cache()
end


--- Remove an item from the items list.
-- @tparam any id The id of the item to remove.
-- @treturn boolean|nil True on success, or nil if id not found.
-- @treturn string|nil Error message if id not found.
-- @usage
--   local success, err = tab_strip:remove_item("tab2")
function TabStrip:remove_item(id)
  -- Find the item to remove
  local remove_index = nil
  local was_selected = false

  for i, item in ipairs(self.items) do
    if item.id == id then
      remove_index = i
      was_selected = (item.id == self.selected)
      break
    end
  end

  if not remove_index then
    return nil, "tab id not found"
  end

  -- Remove the item
  table.remove(self.items, remove_index)
  self:_invalidate_cache()

  -- Adjust selection if needed
  if was_selected then
    if #self.items == 0 then
      -- All tabs removed
      self.selected = nil
      if self.select_cb then
        self.select_cb(self, nil)
      end
    elseif remove_index == 1 then
      -- First tab removed, move to new first tab
      self.selected = self.items[1].id
      if self.select_cb then
        self.select_cb(self, self.selected)
      end
    else
      -- Move selection to left tab
      self.selected = self.items[remove_index - 1].id
      if self.select_cb then
        self.select_cb(self, self.selected)
      end
    end
  end

  return true
end


return TabStrip

