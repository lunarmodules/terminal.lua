--- Screen class for full-screen terminal applications.
-- Manages a full-screen layout with optional header and footer panels (see `ui.panel.Bar`).
-- Derives from `ui.Panel`.
-- @classmod ui.panel.Screen

local utils = require("terminal.utils")
local Panel = require("terminal.ui.panel")
local terminal = require("terminal")

local Screen = utils.class(Panel)

--- Initialize a new Screen instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options (see `Panel:init` for inherited properties)
-- @tparam Panel opts.header Optional header panel (will be (re)named "header")
-- @tparam Panel opts.body Required body panel (will be (re)named "body")
-- @tparam Panel opts.footer Optional footer panel (will be (re)named "footer")
-- @tparam string opts.name Optional name for the screen
-- @see ui.panel.Bar
function Screen:init(opts)
  opts = opts or {}

  -- Validate required body panel
  assert(opts.body, "Screen requires a body panel")
  assert(opts.body:get_type() == "content", "Body panel must be a content panel")

  -- Set names for the panels so they can be looked up later
  if opts.header then
    opts.header.name = "header"
  end
  opts.body.name = "body"
  if opts.footer then
    opts.footer.name = "footer"
  end

  -- Create nested panel structure
  local children

  if opts.header and opts.footer then
    -- Both header and footer: header at top, then vertical split for body/footer
    local body_footer_panel = Panel {
      orientation = Panel.orientations.vertical,
      children = { opts.body, opts.footer }
    }
    children = { opts.header, body_footer_panel }
  elseif opts.header then
    -- Only header: header at top, body below
    children = { opts.header, opts.body }
  elseif opts.footer then
    -- Only footer: body at top, footer below
    children = { opts.body, opts.footer }
  else
    -- No header or footer: create a dummy panel to satisfy the 2-child requirement
    local dummy_panel = Panel {
      name = "dummy",
      visible = false,
      content = function(self) end,
    }
    children = { opts.body, dummy_panel }
  end

  -- Initialize as a vertical panel with the nested structure
  Panel.init(self, {
    orientation = Panel.orientations.vertical,
    children = children,
    name = opts.name or tostring(self)
  })

  -- Track last known terminal size
  self._last_height, self._last_width = terminal.size()
end

--- Check if the terminal has been resized and optionally update the layout.
-- @tparam[opt=false] boolean update Whether to recalculate and redraw if resized
-- @treturn boolean True if the terminal was resized
function Screen:check_resize(update)
  local current_height, current_width = terminal.size()
  local was_resized = (current_height ~= self._last_height) or (current_width ~= self._last_width)

  if was_resized and update then
    self._last_height = current_height
    self._last_width = current_width
    self:calculate_layout()
    self:render()
  end

  return was_resized
end

--- Recalculate the screen layout using current terminal dimensions.
-- Overrides `ui.Panel:calculate_layout` to use full screen dimensions instead of specifying them.
function Screen:calculate_layout()
  local height, width = terminal.size()
  Panel.calculate_layout(self, 1, 1, height, width)
end

return Screen
