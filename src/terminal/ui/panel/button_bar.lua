--- ButtonBar panel for displaying an interactive horizontal row of buttons.
--
-- This class creates a fixed-height panel (1 line of button content) that renders a set
-- of labelled buttons side by side and tracks which one is currently focused. It is
-- designed as the button row of a dialog: the parent panel owns the event loop and
-- decides which keys navigate or confirm; the ButtonBar exposes navigation methods and
-- `get_selection()`.
--
-- To add blank rows above and/or below the buttons, pass a `border` with a blank format,
-- e.g. `border = { format = terminal.draw.box_fmt.blank }`. The border is drawn by the
-- Panel base class and the button content occupies only the inner area.
--
-- **Typical use**
--
-- Place a ButtonBar as the bottom child of a vertically-split panel whose top child
-- holds the dialog prompt or message. In the parent's key handler, call
-- `select_next`/`select_prev` for arrow keys, `select_cancel` for Escape, and
-- `get_selection()` when the confirm key (e.g. Enter) is pressed.
--
-- *Usage:*
--
--     local ButtonBar = require("terminal.ui.panel.button_bar")
--
--     local bar = ButtonBar {
--       items = {
--         { id = "yes",    label = "Yes" },
--         { id = "no",     label = "No" },
--         { id = "cancel", label = "Cancel", cancel = true },
--       },
--       selected = "no",
--       attr     = { fg = "white", bg = "blue" },
--     }
--
--     -- Inside the parent's key-dispatch loop:
--     if key == keys.left   then bar:select_prev() end
--     if key == keys.right  then bar:select_next() end
--     if key == keys.escape then bar:select_cancel() end
--     if key == keys.enter  then
--       local id = bar:get_selection()
--       -- act on id
--     end
--
-- @classmod ui.panel.ButtonBar

local Panel = require("terminal.ui.panel.init")
local utils = require("terminal.utils")
local terminal = require("terminal")
local text = require("terminal.text")
local Sequence = require("terminal.sequence")
local width = require("terminal.text.width")



local ButtonBar = utils.class(Panel)



do
  local confirm = require("terminal.cli.confirm")
  --- Response ID constants. Plain strings used as `value` fields in the preset `sets`.
  -- Copy of `cli.Confirm.ids`.
  -- @table Confirm.ids
  ButtonBar.ids = confirm.ids

  --- Preset item sets. Each is an array, where the values are has tables; `{label, value, cancel?}`.
  -- These are ready to pass as `opts.items`, as the most common sets.
  -- Copy of `cli.Confirm.sets`.
  -- @table Confirm.sets
  ButtonBar.sets = confirm.sets
end



-- Validate and normalise the items array.
-- Returns processed items and the index of the cancel item (or nil).
local function validate_items(items)
  assert(type(items) == "table", "items must be a table")

  local cancel_idx = nil
  local processed = {}

  for i, item in ipairs(items) do
    assert(type(item) == "table", "each item must be a table, at index " .. i)
    assert(type(item.label) == "string", "each item must have a string label, at index " .. i)

    if item.cancel then
      assert(not cancel_idx, "at most one item may have cancel = true")
      cancel_idx = i
    end

    processed[i] = {
      id     = item.id or i,
      label  = item.label,
      cancel = not not item.cancel,
    }
  end

  return processed, cancel_idx
end



-- Return the selected id when it exists in items, or the first item's id when selected is nil.
-- Raises an error when selected is provided but not found.
local function resolve_selected(items, selected)
  if selected == nil then
    return (items[1] or {}).id
  end

  for _, item in ipairs(items) do
    if item.id == selected then
      return selected
    end
  end
  error("selected id not found in items: " .. tostring(selected))
end



-- Return a shallow copy of source with the `reverse` field inverted.
local function derive_attr(source)
  local derived = {}
  for k, v in pairs(source) do
    derived[k] = v
  end
  derived.reverse = not derived.reverse
  return derived
end



-- Return the index of the item with the given id.
-- Returns nil + error string when not found.
-- @tparam ButtonBar self The ButtonBar instance.
-- @tparam any id The id to find.
local function find_item_idx(self, id)
  for i, item in ipairs(self.items) do
    if item.id == id then
      return i
    end
  end
  return nil, "id not found: " .. tostring(id)
end



--- Create a new ButtonBar instance.
-- Do not call this method directly, call on the class instead. See example.
-- @tparam table opts Configuration options (see `Panel:init` for inherited properties).
-- @tparam table opts.items Array of button items. Each entry must have a `label` field
-- (string) and may have an `id` field (any; defaults to the item's index) and a `cancel`
-- field (boolean; marks this button as the cancel action). At most one item may carry
-- `cancel = true`.
-- @tparam[opt] any opts.selected Id of the button that receives initial focus.
-- Defaults to the first item.
-- @tparam[opt="["] string opts.prefix String prepended to every button label when rendered.
-- @tparam[opt="]"] string opts.postfix String appended to every button label when rendered.
-- @tparam[opt=1] number opts.padding Number of spaces rendered between adjacent buttons.
-- @tparam[opt] number opts.button_min_width Minimum display-column width for each button cell
-- (prefix + label + postfix combined). Cells are padded with spaces when the content is shorter.
-- @tparam[opt] number opts.button_max_width Maximum display-column width for each button cell
-- (prefix + label + postfix combined). Labels that exceed this are truncated with an
-- ellipsis via `text.width.truncate_ellipsis`.
-- @tparam[opt=false] boolean opts.auto_render When true, automatically re-renders the panel
-- whenever the selection changes via `select`, `select_next`, `select_prev`, or `select_cancel`.
-- @tparam[opt] table opts.attr Text attributes applied to the entire bar background,
-- including the spaces between and around buttons (e.g. `{ fg = "white", bg = "blue" }`).
-- @tparam[opt] table opts.button_attr Text attributes applied to unselected buttons.
-- When omitted and `opts.attr` is provided, derived automatically by inverting the
-- `reverse` field of `opts.attr`.
-- @tparam[opt] table opts.selected_attr Text attributes applied to the focused button.
-- When omitted, derived automatically by inverting the `reverse` field of `opts.button_attr`.
-- @treturn ButtonBar A new ButtonBar instance.
-- @usage
--   local ButtonBar = require("terminal.ui.panel.button_bar")
--   local bar = ButtonBar {
--     items = {
--       { label = "OK" },
--       { label = "Cancel", cancel = true },
--     },
--   }
function ButtonBar:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(opts.items ~= nil, "items is required")

  local items, cancel_idx = validate_items(opts.items)
  local selected = resolve_selected(items, opts.selected)
  local prefix = opts.prefix or "["
  local postfix = opts.postfix or "]"
  local padding = opts.padding or 1
  local button_min_width = opts.button_min_width or 1
  local button_max_width = opts.button_max_width or math.huge
  local auto_render = not not opts.auto_render
  local attr = opts.attr
  local button_attr = opts.button_attr
  local selected_attr = opts.selected_attr

  opts.min_height = 1
  opts.max_height = 1
  opts.size_mode = Panel.size_modes.inner

  opts.content = function(self)
    self:_draw_buttonbar()
  end

  -- calculate minimum panel width based on the items and options (inner; border overhead added by Panel)
  opts.min_width = (width.utf8swidth(prefix .. postfix) + padding + button_min_width) * #items - padding

  opts.items = nil
  opts.selected = nil
  opts.prefix = nil
  opts.postfix = nil
  opts.padding = nil
  opts.button_min_width = nil
  opts.button_max_width = nil
  opts.auto_render = nil
  opts.attr = nil
  opts.button_attr = nil
  opts.selected_attr = nil

  Panel.init(self, opts)

  if not button_attr and attr then
    button_attr = derive_attr(attr)
  end

  if not selected_attr and button_attr then
    selected_attr = derive_attr(button_attr)
  end

  if not selected_attr then
    selected_attr = { reverse = true }
  end

  self.items = items
  self.cancel_idx = cancel_idx
  self.selected = selected
  self.prefix = prefix
  self.postfix = postfix
  self.padding = padding
  self.button_min_width = button_min_width
  self.button_max_width = button_max_width
  self.auto_render = auto_render
  self.attr = attr
  self.button_attr = button_attr
  self.selected_attr = selected_attr
end



-- Draws the button bar unconditionally.
function ButtonBar:_draw_buttonbar()

  -- create list of labels, extended/shortened to fit within button_min_width and button_max_width
  local labels = {}
  local tot_label_width = #self.items * width.utf8swidth(self.prefix .. self.postfix)

  for i, item in ipairs(self.items) do
    local label = item.label
    local label_width = width.utf8swidth(label)
    if label_width > self.button_max_width then
      -- to big, truncate with ellipsis
      label = width.truncate_ellipsis(self.button_max_width, label)
      label_width = width.utf8swidth(label)
      -- if truncated mid double-width char then we might now be too short
      -- so continue check against button_min_width after truncation
    end

    if label_width < self.button_min_width then
      -- to small, center the text
      local padding_needed = self.button_min_width - label_width
      local left_padding = math.floor(padding_needed / 2)
      local right_padding = padding_needed - left_padding
      label = (" "):rep(left_padding) .. label .. (" "):rep(right_padding)
      label_width = self.button_min_width
    end

    labels[i] = label
    tot_label_width = tot_label_width + label_width
  end

  local buttons_total = tot_label_width + (#self.items - 1) * self.padding
  local pad_left = math.floor((self.inner_width - buttons_total) / 2)
  local pad_right = self.inner_width - buttons_total - pad_left


  -- build the output sequence
  local s = Sequence()

  -- backup cursor pos, and apply bar background attr if given
  s[#s+1] = terminal.cursor.position.backup_seq()
  if self.attr then
    s[#s+1] = function() return text.push_seq(self.attr) end
  end

  -- position on the button line and write left centering padding
  s[#s+1] = function() return terminal.cursor.position.set_seq(self.inner_row, self.inner_col) end
  s[#s+1] = (" "):rep(pad_left)

  -- draw each button with inter-button padding
  for i, item in ipairs(self.items) do
    -- set attributes based on selection state
    if item.id == self.selected then
      s[#s+1] = function() return text.push_seq(self.selected_attr or {}) end
    else
      s[#s+1] = function() return text.push_seq(self.button_attr or {}) end
    end

    s[#s+1] = self.prefix
    s[#s+1] = labels[i]
    s[#s+1] = self.postfix

    s[#s+1] = text.pop_seq
    if i < #self.items then
      s[#s+1] = (" "):rep(self.padding)
    end
  end

  -- write right centering padding
  s[#s+1] = (" "):rep(pad_right)

  -- restore cursor pos and attributes
  if self.attr then
    s[#s+1] = text.pop_seq
  end
  s[#s+1] = terminal.cursor.position.restore_seq()

  -- write the sequence to the terminal
  terminal.output.write(s)
end



--- Returns the preferred minimum outer width. At this width all buttons render at their
-- maximum display size with the least truncation. Includes any border width overhead.
-- Can be used by parent dialogs to compute their own preferred width.
-- @treturn number The preferred minimum outer width in columns.
function ButtonBar:preferred_min_width()
  local total = 0
  local pw = width.utf8swidth(self.prefix .. self.postfix)
  for _, item in ipairs(self.items) do
    local w = width.utf8swidth(item.label)
    if w > self.button_max_width then w = self.button_max_width end
    if w < self.button_min_width then w = self.button_min_width end
    total = total + pw + w
  end
  local border_w = 0
  if self.border then
    local fmt = self.border.format
    border_w = width.utf8swidth(fmt.l or "") + width.utf8swidth(fmt.r or "")
  end
  return total + (#self.items - 1) * self.padding + border_w
end



--- Get the id of the currently focused button.
-- @treturn any The focused button id.
function ButtonBar:get_selection()
  return self.selected
end



--- Move focus to the button with the given id.
-- Re-renders when `auto_render` is true and the selection changed.
-- @tparam any id The id of the button to focus.
-- @treturn any The id of the currently focused button after the operation.
-- @treturn string An error message when the given id does not exist in the items.
function ButtonBar:select(id)
  local idx, err = find_item_idx(self, id)

  if idx and self.selected ~= id then
    -- it exists and it is a change over the current selection
    self.selected = id
    if self.auto_render then
      self:render()
    end
  end

  return self.selected, err
end



--- Move focus to the next (right) button.
-- Has no effect when the last button is already focused; does not wrap around.
-- Re-renders when `auto_render` is true and the selection changed.
-- @treturn any The id of the currently focused button after the operation.
function ButtonBar:select_next()
  local idx = find_item_idx(self, self.selected)
  local next_idx = math.min(idx + 1, #self.items)
  return self:select(self.items[next_idx].id)
end



--- Move focus to the previous (left) button.
-- Has no effect when the first button is already focused; does not wrap around.
-- Re-renders when `auto_render` is true and the selection changed.
-- @treturn any The id of the currently focused button after the operation.
function ButtonBar:select_prev()
  local idx = find_item_idx(self, self.selected)
  local prev_idx = math.max(idx - 1, 1)
  return self:select(self.items[prev_idx].id)
end



--- Move focus to the cancel-marked button.
-- Useful when the parent receives an Escape key press.
-- Always returns the currently focused button id (first return is always truthy).
-- The second return value signals whether the move was successful: it is `nil` on success
-- and an error string when no cancel button is defined (in which case focus does not move).
-- Re-renders when `auto_render` is true and the selection changed.
-- @treturn any The id of the currently focused button after the operation.
-- @treturn string `"no cancel button"` when no item is marked with `cancel = true`.
function ButtonBar:select_cancel()
  if not self.cancel_idx then
    return self.selected, "no cancel button"
  end
  return self:select(self.items[self.cancel_idx].id)
end



return ButtonBar
