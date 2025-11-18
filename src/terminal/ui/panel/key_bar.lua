--- Key bar panel for displaying keyboard shortcuts.
--
-- This class creates a fixed-height panel (1 or 2 lines) that displays
-- keyboard shortcuts in equally wide cells, similar to editors like
-- nano or tools like htop.
--
-- Each cell shows a key and a description with separate text attributes.
-- When configured for 2 rows, columns are aligned vertically.
-- @classmod ui.panel.KeyBar

local Panel = require("terminal.ui.panel.init")
local terminal = require("terminal")
local utils = require("terminal.utils")
local text = require("terminal.text")
local Sequence = require("terminal.sequence")

local KeyBar = utils.class(Panel)


--- Create a new KeyBar instance.
-- A key-bar is a 1 or 2 line `panel` that displays keyboard shortcuts
-- in equally wide columns.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options (see `Panel:init` for inherited properties)
-- @tparam[opt=1] number opts.margin Number of spaces from left and right edges.
-- @tparam[opt=2] number opts.padding Minimum number of spaces between columns.
-- @tparam[opt=" "] string opts.separator Separator string between key and description.
-- @tparam[opt] table opts.attr Text attributes for the entire bar area.
-- @tparam[opt] table opts.key_attr Text attributes for the key labels.
-- @tparam[opt] table opts.desc_attr Text attributes for the descriptions.
-- @tparam[opt] table opts.items Array of `{ key = string, desc = string }` items.
-- @tparam[opt=1] number opts.rows Number of rows (1 or 2).
-- @tparam[opt=false] boolean opts.auto_render Whether to auto-render on updates.
-- @treturn KeyBar A new KeyBar instance.
function KeyBar:init(opts)
  opts = opts or {}

  -- Extract specific options before calling parent
  local margin = opts.margin or 1
  local padding = opts.padding or 2
  local separator = opts.separator or " "
  local items = opts.items or {}
  local rows = (opts.rows == 2) and 2 or 1
  local attr = opts.attr
  local key_attr = opts.key_attr
  local desc_attr = opts.desc_attr
  local auto_render = not not opts.auto_render -- force boolean

  -- Set fixed height of 1 or 2 lines
  opts.min_height = rows
  opts.max_height = rows

  -- Cleanup to avoid conflicts with Panel
  opts.margin = nil
  opts.padding = nil
  opts.separator = nil
  opts.items = nil
  opts.rows = nil
  opts.attr = nil
  opts.key_attr = nil
  opts.desc_attr = nil
  opts.auto_render = nil

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw()
  end

  -- Call parent constructor
  Panel.init(self, opts)
  self.clear_content = false

  -- Set properties
  self.margin = margin
  self.padding = padding
  self.separator = separator
  self.attr = attr
  self.key_attr = key_attr
  self.desc_attr = desc_attr
  self.auto_render = false -- prevent render during initialization
  self:set_items(items)
  self:set_rows(rows)
  self.auto_render = auto_render
end


-- Private: draw the key bar content
function KeyBar:_draw()
  local lines = self:_build_lines(self.inner_width)
  if #lines == 0 then
    return
  end
  terminal.output.write(
    terminal.cursor.position.backup_seq(),
    terminal.cursor.position.set_seq(self.inner_row, self.inner_col),
    lines[1] or "",
    (self.inner_height > 1) and terminal.cursor.position.set_seq(self.inner_row + 1, self.inner_col) or "",
    (self.inner_height > 1) and (lines[2] or "") or "",
    terminal.cursor.position.restore_seq()
  )
end


-- Private: build one or two line sequences
-- @tparam number width Available width for the bar area
-- @treturn table Array of 1 or 2 Sequence objects
function KeyBar:_build_lines(width)
  if width <= 0 then
    return {}
  end

  local items = self.items or {}
  local rows = self.rows
  local total = #items
  if total == 0 then
    local s = Sequence(string.rep(" ", math.max(0, width - 0)))
    s[#s+1] = terminal.clear.eol_seq
    return { s, (rows == 2) and s or nil }
  end

  local cols = (rows == 2) and math.ceil(total / 2) or total

  -- Calculate layout
  local margin_space = self.margin * 2
  local padding_gaps = math.max(0, cols - 1)
  local available_content_space = width - margin_space - (self.padding * padding_gaps)
  if available_content_space < 0 then
    local s = Sequence(string.rep(" ", math.max(0, width)))
    return { s }
  end

  local base_cell = math.floor(available_content_space / cols)
  local extra = available_content_space - (base_cell * cols)

  local cell_widths = {}
  for i = 1, cols do
    cell_widths[i] = base_cell + ((i <= extra) and 1 or 0)
  end

  -- Split items across rows
  local top = {}
  local bottom = {}
  if rows == 2 then
    for i = 1, cols do top[i] = items[i] end
    for i = 1, total - cols do bottom[i] = items[cols + i] end
  else
    for i = 1, cols do top[i] = items[i] end
  end

  local function build_row(row_items)
    local s = Sequence()
    if self.attr then
      s[#s+1] = function() return text.stack.push_seq(self.attr) end
    end
    s[#s+1] = string.rep(" ", self.margin)
    for c = 1, cols do
      local item = row_items[c]
      local cw = cell_widths[c]
      local key_str = ""
      local key_w = 0
      local desc_str = ""
      local desc_w = 0
      if item then
        local k = item.key or ""
        local d = item.desc or ""
        key_w = text.width.utf8swidth(k)
        desc_w = text.width.utf8swidth(d)

        local have_desc = (d ~= "")

        -- truncate desc first if needed
        local separator_w = have_desc and text.width.utf8swidth(self.separator) or 0
        local max_desc_w = math.max(0, cw - key_w - separator_w)
        if desc_w > max_desc_w then
          local t, tw = utils.truncate_ellipsis(max_desc_w, d, "right")
          d = t; desc_w = tw
        end
        -- if still too wide, truncate key
        local max_key_w = math.max(0, cw - desc_w - separator_w)
        if key_w > max_key_w then
          local t, tw = utils.truncate_ellipsis(max_key_w, k, "right")
          k = t; key_w = tw
        end

        key_str = k
        desc_str = (have_desc and (desc_w > 0)) and d or ""
      end

      -- Calculate separator width for written width calculation
      local separator_w = (desc_str ~= "") and text.width.utf8swidth(self.separator) or 0

      -- write key (with attr)
      if self.key_attr and key_str ~= "" then
        s[#s+1] = function() return text.stack.push_seq(self.key_attr) end
        s[#s+1] = key_str
        s[#s+1] = text.stack.pop_seq
      else
        s[#s+1] = key_str
      end

      -- separator between key and desc
      if desc_str ~= "" then
        s[#s+1] = self.separator
      end

      -- write desc (with attr)
      if self.desc_attr and desc_str ~= "" then
        s[#s+1] = function() return text.stack.push_seq(self.desc_attr) end
        s[#s+1] = desc_str
        s[#s+1] = text.stack.pop_seq
      else
        s[#s+1] = desc_str
      end

      -- pad to full cell width
      local written_w = key_w + (desc_str ~= "" and separator_w or 0) + desc_w
      local pad = math.max(0, cw - written_w)
      if pad > 0 then
        s[#s+1] = string.rep(" ", pad)
      end

      -- inter-column padding
      if c < cols then
        s[#s+1] = string.rep(" ", self.padding)
      end
    end
    s[#s+1] = string.rep(" ", self.margin)
    if self.attr then
      s[#s+1] = text.stack.pop_seq
    end
    return s
  end

  local line1 = build_row(top)
  if rows == 2 then
    local line2 = build_row(bottom)
    return { line1, line2 }
  end
  return { line1 }
end


--- Set the items (shortcuts) to display.
-- @tparam table items Array of `{ key = string, desc = string }` items.
function KeyBar:set_items(items)
  items = items or {}
  self.items = items
  if self.auto_render then
    self:render()
  end
end


--- Set the number of rows (1 or 2).
-- Adjusts height constraints accordingly.
-- @tparam number rows 1 or 2
function KeyBar:set_rows(rows)
  rows = (rows == 2) and 2 or 1
  if self.rows == rows then
    return
  end
  self.rows = rows
  self._min_height = rows
  self._max_height = rows
  if self.auto_render then
    self:render()
  end
end


return KeyBar


