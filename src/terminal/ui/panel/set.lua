--- Panel set for managing multiple named panels with single selection.
--
-- This class holds a set of content panels (by unique name) of which at most
-- one is visible/active at a time. It is designed to be used in combination
-- with a tab-control: switching a tab simply calls `select(name)`.
--
-- Internally, this is implemented as a divided `Panel` with two children where
-- child[1] is the currently selected panel and child[2] is a dummy panel. This
-- preserves the invariant that parent panels must always have two children.
--
--
-- @classmod ui.panel.Set

local Panel = require("terminal.ui.panel.init")
local utils = require("terminal.utils")

-- Module-level dummy panel constant for equality checks
local DUMMY_PANEL = Panel {
  content = function() end,
  visible = false,
  name = "__dummy__",
}

local Set = utils.class(Panel)

--- Create a new Set instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Options (any Panel options that make sense for a divided parent)
-- @tparam[opt] string opts.name Optional name for the set panel itself
-- @tparam[opt] table opts.children Optional initial array of child panels (0..n)
-- @tparam[opt] string opts.selected Optional name to select initially
-- @treturn Set A new Set instance
function Set:init(opts)
  opts = opts or {}

  -- Store original children before overriding
  local initial_children = opts.children

  -- Always behave as a divided panel; orientation is arbitrary
  opts.orientation = Panel.orientations.horizontal
  opts.content = nil
  opts.children = { DUMMY_PANEL, DUMMY_PANEL }

  Panel.init(self, opts)

  -- Initialize from original children if provided (0..n)
  if initial_children then
    for _, panel in ipairs(initial_children) do
      self:add(panel)
    end
  end

  local initial = opts.selected
  if not initial then
    -- Select any available panel
    local iter = self:panels()
    local first_panel = iter()
    initial = first_panel and first_panel.name or nil
  end
  if initial then
    self:select(initial)
  end
end


--- Add a panel to the set.
-- Accepts the panel; its name is derived from `panel.name`.
-- When `jump` is truthy, the newly added panel is selected; otherwise the
-- current selection is preserved (if any). If there was no selection yet,
-- the newly added panel becomes selected regardless of `jump`.
-- @tparam table panel The panel instance to add
-- @tparam[opt=false] boolean jump Select the newly added panel when truthy
-- @return nothing
function Set:add(panel, jump)
  -- Wrap existing children and add new panel at top
  local wrapper = Panel {
    orientation = Panel.orientations.horizontal,
    children = {
      self.children[1],
      self.children[2],
    }
  }
  self.children[1] = panel
  self.children[2] = wrapper

  local current_selection = self:get_selected()
  if not current_selection or jump then
    self:select(panel.name)
  else
    panel:hide(true)
  end
end


--- Remove a panel from the set by name.
-- If the removed panel is currently selected, another available panel will be
-- selected automatically (any available panel) or the set becomes empty.
-- @tparam string name The panel name to remove
-- @treturn[1] Panel The removed panel
-- @treturn[2] nil If the panel was not found
-- @treturn[2] string Error message
function Set:remove(name)

  local curr = self
  local removed = nil
  while curr ~= DUMMY_PANEL do
    if curr.children[1].name == name then
      -- found it, remove it
      removed = curr.children[1]
      curr.children = curr.children[2]
      break
    end
    curr = curr.children[2]
  end

  if not removed then
    return nil, "panel not found: " .. tostring(name)
  end

  if removed:visible() then
    -- this was the selected one, change selection to the next available panel
    if curr.children[1] ~= DUMMY_PANEL then
      self:select(curr.children[1].name)
    end
  end

  return removed
end


--- Select an existing panel by name (makes it visible).
-- All other panels are hidden.
-- @tparam string name Panel name to select
-- @treturn[1] true If the panel was found and selected
-- @treturn[2] nil If the panel was not found
-- @treturn[2] string Error message
function Set:select(name)
  local old_selection = nil
  local found = false
  for p in self:panels() do
    if p.name == name then
      -- found it, make it visible
      p:hide(false)
      found = true
    else
      -- not our panel, hide it if visible (current selection)
      if p:visible() then
        p:hide(true)
        old_selection = p
      end
    end
  end

  if not found then
    if old_selection then
      old_selection:hide(false) -- restore old selection
    end
    return nil, "panel not found: " .. tostring(name)
  end

  return true
end


--- Get the currently selected panel name.
-- @treturn[1] string Name of the selected panel
-- @treturn[2] nil If none selected
-- @treturn[2] string Error message
function Set:get_selected()
  for p in self:panels() do
    if p:visible() then
      return p.name
    end
  end

  return nil, "no panel selected in set"
end


--- Iterator for traversing panels in the tree.
-- @return iterator function that yields panel instances
function Set:panels()
  local curr = self
  return function()
    local nxt = curr.children[1]
    if nxt == DUMMY_PANEL then
      return nil
    end
    curr = curr.children[2]
    return nxt
  end
end


--- Get all panel names.
-- @treturn table Set of names (order not guaranteed)
function Set:get_names()
  local names = {}
  for p in self:panels() do
    names[#names + 1] = p.name
  end
  return names
end







return Set


