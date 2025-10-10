--- Text Panel class for displaying scrollable text content.
-- Derives from `ui.Panel`.
-- @classmod ui.panel.Text_panel


local Panel = require("terminal.ui.panel.init")
local terminal = require("terminal")
local utils = require("terminal.utils")
local text = require("terminal.text")
local Sequence = require("terminal.sequence")


local TextPanel = utils.class(Panel)


--- Create a new TextPanel instance.
-- @tparam table opts Options for the text panel.
-- @tparam[opt] table opts.lines Array of text lines to display.
-- @tparam[opt=1] number opts.scroll_step Number of lines to scroll at a time.
-- @tparam[opt=1] number opts.initial_position Initial scroll position (1-based line number).
-- @tparam[opt] table opts.text_attr Text attributes to apply to all displayed text.
-- @tparam[opt=false] boolean opts.auto_render Whether to automatically re-render when content changes.
-- @treturn TextPanel A new TextPanel instance.
-- @usage
--   local TextPanel = require("terminal.ui.panel.text_panel")
--   local panel = TextPanel {
--     lines = {"Line 1", "Line 2", "Line 3"},
--     scroll_step = 2,
--     initial_position = 1,
--     text_attr = { fg = "green", brightness = "bright" }
--   }
--   panel:go_to(5)  -- Go to line 5
--   panel:scroll_down()  -- Scroll down by scroll_step
function TextPanel:init(opts)
  opts = opts or {}

  -- Extract text panel specific options
  local lines = opts.lines or {}
  local scroll_step = opts.scroll_step or 1
  local initial_position = opts.initial_position or 1
  local text_attr = opts.text_attr
  local auto_render = not not opts.auto_render -- force to boolean

  -- Remove text panel specific options from opts to avoid conflicts with Panel
  opts.lines = nil
  opts.scroll_step = nil
  opts.initial_position = nil
  opts.text_attr = nil
  opts.auto_render = nil

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw_text()
  end

  -- Call parent constructor
  Panel.init(self, opts)

  -- Set text panel specific properties
  self.scroll_step = scroll_step
  self.text_attr = text_attr

  self.auto_render = false -- set to false initially to prevent render during initialization
  self.formatted_lines = nil
  self:set_lines(lines)
  self:go_to(initial_position)
  self.auto_render = auto_render -- set actual value after initialization
end



-- Private method to draw the text content.
-- @return nothing
function TextPanel:_draw_text()
  -- Ensure formatted lines are available
  if not self.formatted_lines then
    self:_rebuild_formatted_lines()
  end

  local seq = Sequence()
  seq[1] = terminal.cursor.position.backup_seq()
  local n = 2

  -- Add text attributes if specified
  if self.text_attr then
    seq[n] = terminal.text.stack.push_seq(self.text_attr)
    n = n + 1
  end

  -- Add each visible line to the sequence
  local start_line = self.position
  local end_line = math.min(start_line + self.inner_height - 1, #self.formatted_lines)
  for i = start_line, end_line do
    local line_row = self.inner_row + (i - start_line)
    -- Add cursor positioning and text to sequence
    seq[n] = terminal.cursor.position.set_seq(line_row, self.inner_col)
    seq[n+1] = self.formatted_lines[i]
    n = n + 2
  end

  -- Pop text attributes if they were pushed
  if self.text_attr then
    seq[n] = terminal.text.stack.pop_seq()
    n = n + 1
  end

  seq[n] = terminal.cursor.position.restore_seq()

  -- Write everything at once
  terminal.output.write(seq)
end



--- Method to format a line to fit the available width.
-- Returned lines must be padded with spaces to prevent having to clear lines.
-- @tparam string line The line text to format.
-- @tparam number max_width Maximum width in display columns.
-- @treturn table Array of formatted lines
function TextPanel:format_line(line, max_width)
  line = line or ""

  local cols = text.width.utf8swidth(line)

  if cols == max_width then
    return {line}
  end

  if cols > max_width then   -- truncate too long a line
    line = utils.utf8sub_col(line, 1, max_width)
    return {line}
  end

  -- pad too short a line with spaces
  return {line .. string.rep(" ", max_width - cols)}
end


-- Internal: rebuild formatted_lines from source lines for current width
function TextPanel:_rebuild_formatted_lines()
  assert(self.inner_width, "inner_width is not set, cannot rebuild formatted_lines, call calculate_layout first")
  local width = self.inner_width
  local out = {}
  for i, line in ipairs(self.lines) do
    for _, formatted_line in ipairs(self:format_line(line, width)) do
      table.insert(out, formatted_line)
    end
  end
  self.formatted_lines = out

  -- ensure the position is valid since number of lines might have changed, but
  -- we don't want to render in the middle of this process
  local auto_render = self.auto_render
  self.auto_render = false
  self:go_to(self.position)
  self.auto_render = auto_render
end



--- Go to a specific line position.
-- @tparam number position The line position to go to (1-based).
-- @return nothing
function TextPanel:go_to(position)
  if not self.inner_width then
    -- there is no inner-width set, so we cannot calculate the position,
    -- since any wrapping lines can be 1 or more lines, hence unknown total size.
    -- Just accept position, when reformatting lines in rebuild_formatted_lines we
    -- will call go_to again, and by then we can validate the position.
    -- So for now just accept the value set.
    self.position = position -- there is no width, so auto_render is irrelevant here (see below)
    return
  end

  local old_position = self.position

  if not self.formatted_lines then
    -- width is known, but we haven't formatted yet. Just format
    -- since formatting will call go_to again with auto-render disabled, so
    -- we do need the auto_render check afterwards.
    self.position = position
    self:_rebuild_formatted_lines() -- this will update position within bounds-check
  else
    -- we have the formatted lines, do bounds check before setting position
    position = math.max(1, position)
    position = math.min(position, math.max(1, #self.formatted_lines - self.inner_height + 1))
    self.position = position
  end

  if self.auto_render and self.position ~= old_position then
    self:render()
  end
end


-- Rebuild formatted lines when layout changes width
function TextPanel:calculate_layout(parent_row, parent_col, parent_height, parent_width)
  Panel.calculate_layout(self, parent_row, parent_col, parent_height, parent_width)

  -- Only rebuild if formatted_lines exists and width has changed
  local l1 = (self.formatted_lines or {})[1]
  if l1 then
    local old_width = text.width.utf8swidth(l1)
    if old_width ~= self.inner_width then
      self.formatted_lines = nil
    end
  end
end



--- Scroll up by scroll_step lines.
-- @return nothing
function TextPanel:scroll_up()
  self:go_to(self.position - self.scroll_step)
end



--- Scroll down by scroll_step lines.
-- @return nothing
function TextPanel:scroll_down()
  self:go_to(self.position + self.scroll_step)
end



--- Scroll up by one page (inner_height lines).
-- @return nothing
function TextPanel:page_up()
  if not self.inner_height then
    return
  end
  self:go_to(self.position - self.inner_height)
end



--- Scroll down by one page (inner_height lines).
-- @return nothing
function TextPanel:page_down()
  if not self.inner_height then
    return
  end
  self:go_to(self.position + self.inner_height)
end



--- Get the current scroll position.
-- @treturn number The current line position (1-based).
function TextPanel:get_position()
  return self.position
end



--- Get the total number of lines.
-- @treturn number The total number of lines.
function TextPanel:get_line_count()
  if not self.formatted_lines then
    self:_rebuild_formatted_lines()
  end

  return #self.formatted_lines
end



--- Set new text lines.
-- @tparam table lines Array of text lines.
-- @return nothing
function TextPanel:set_lines(lines)
  self.lines = lines or {}
  self.formatted_lines = nil
  self.position = 1  -- Reset to top
  if self.auto_render then
    self:render()
  end
end



--- Add a line to the text content.
-- @tparam string line The line to add.
-- @return nothing
function TextPanel:add_line(line)
  table.insert(self.lines, line or "")

  local width = self.inner_width
  local formatted_lines = self.formatted_lines

  if width and formatted_lines then
    local old_line_count = #formatted_lines
    for _, formatted_line in ipairs(self:format_line(line, width)) do
      table.insert(formatted_lines, formatted_line)
    end

    if self.auto_render then
      -- only write the new lines if they are inside the viewport
      local lastline_displayed = self.position + self.inner_height - 1
      if lastline_displayed > old_line_count then
        self:render()
      end
    end
  end
end



--- Clear all text content.
-- @return nothing
function TextPanel:clear_lines()
  self.lines = {}
  self.formatted_lines = nil
  self.position = 1
  if self.auto_render then
    self:render()
  end
end



return TextPanel
