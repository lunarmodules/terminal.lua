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

  -- Remove text panel specific options from opts to avoid conflicts with Panel
  opts.lines = nil
  opts.scroll_step = nil
  opts.initial_position = nil
  opts.text_attr = nil

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw_text()
  end

  -- Call parent constructor
  Panel.init(self, opts)

  -- Set text panel specific properties
  self.lines = lines
  self.scroll_step = scroll_step
  self.position = initial_position
  self.text_attr = text_attr
end



-- Private method to draw the text content.
-- @return nothing
function TextPanel:_draw_text()
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
  local end_line = math.min(start_line + self.inner_height - 1, #self.lines)
  for i = start_line, end_line do
    local line_text = self.lines[i] or ""
    local line_row = self.inner_row + (i - start_line)

    -- Truncate line if too long
    local display_text = self:_truncate_line(line_text, self.inner_width)

    -- Add cursor positioning and text to sequence
    seq[n] = terminal.cursor.position.set_seq(line_row, self.inner_col)
    seq[n+1] = display_text
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



-- Private method to truncate a line to fit the available width.x
-- @tparam string line The line text to truncate.
-- @tparam number max_width Maximum width in display columns.
-- @treturn string The truncated line.
function TextPanel:_truncate_line(line, max_width)
  line = line or ""

  local cols = text.width.utf8swidth(line)

  if cols == max_width then
    return line
  end

  if cols > max_width then   -- truncate too long a line
    line = utils.utf8sub_col(line, 1, max_width)
    return line
  end

  -- pad too short a line with spaces
  return line .. string.rep(" ", max_width - cols)
end



--- Go to a specific line position.
-- @tparam number position The line position to go to (1-based).
-- @return nothing
function TextPanel:go_to(position)
  position = math.max(1, position)
  -- position = math.min(position, math.max(1, #self.lines - self.inner_height + 1))
  position = math.min(position, math.max(1, #self.lines))

  if self.position ~= position then
    self.position = position
    self:render()
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



--- Get the current scroll position.
-- @treturn number The current line position (1-based).
function TextPanel:get_position()
  return self.position
end



--- Get the total number of lines.
-- @treturn number The total number of lines.
function TextPanel:get_line_count()
  return #self.lines
end



--- Set new text lines.
-- @tparam table lines Array of text lines.
-- @return nothing
function TextPanel:set_lines(lines)
  self.lines = lines or {}
  self.position = 1  -- Reset to top
  self:render()
end



--- Add a line to the text content.
-- @tparam string line The line to add.
-- @return nothing
function TextPanel:add_line(line)
  table.insert(self.lines, line or "")
  self:render()
end



--- Clear all text content.
-- @return nothing
function TextPanel:clear_lines()
  self.lines = {}
  self.position = 1
  self:render()
end



return TextPanel
