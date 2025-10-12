--- TextPanel class for displaying and navigating scrollable text content.
--
-- The TextPanel provides a powerful interface for displaying text content that doesn't fit on a single screen
-- with efficient scrolling, navigation, and content management capabilities. It's designed
-- for applications that need to display logs, documentation, or any scrollable text content.
--
-- **Key Features**
--
-- - Inherits from `Panel` class, so it supports all the features of the `Panel` class.
--
-- Navigation & Scrolling:
--
-- - Line-by-line scrolling with configurable step size
-- - Page-based navigation (scroll by viewport height)
-- - Direct positioning to any line or "go to bottom"
-- - Highlighting a line for selection
--
-- Content Management:
--
-- - Dynamic line addition and removal
-- - Automatic line rotation with `max_lines` option
-- - Text truncation/wrapping/word-wrapping and padding with UTF-8 support
-- - Automatic re-rendering with `auto_render` option
--
-- **Usage Examples**
--
-- Basic text display:
--
--        local panel = TextPanel {
--          lines = {"Line 1", "Line 2", "Line 3"},
--          scroll_step = 1,
--          auto_render = true,
--          line_formatter = TextPanel.format_line_wordwrap,
--        }
--
-- Log viewer with line limits:
--
--        local log_panel = TextPanel {
--          max_lines = 200,  -- Keep only last 200 lines
--          text_attr = { fg = "green" },
--          auto_render = true
--        }
--        log_panel:add_line("New log entry")
-- @classmod ui.panel.Text


local Panel = require("terminal.ui.panel.init")
local terminal = require("terminal")
local utils = require("terminal.utils")
local text = require("terminal.text")
local Sequence = require("terminal.sequence")
local EditLine = require("terminal.editline")


local TextPanel = utils.class(Panel)


--- Create a new TextPanel instance.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts Configuration options (see `Panel:init` for inherited properties)
-- @tparam[opt] table opts.lines Array of text lines to display.
-- @tparam[opt=1] number opts.scroll_step Number of lines to scroll at a time.
-- @tparam[opt=1] number opts.initial_position Initial scroll position (1-based line number).
-- @tparam[opt] table opts.text_attr Text attributes to apply to all displayed text.
-- @tparam[opt=false] boolean opts.auto_render Whether to automatically re-render when content changes.
-- @tparam[opt] number opts.max_lines Maximum number of lines to keep (older lines are removed when
-- exceeded upon a call to `add_line`).
-- @tparam[opt] function opts.line_formatter Line formatter function to use (defaults to format_line_truncate).
-- see `set_line_formatter` for more details.
-- @tparam[opt] number opts.highlight Source line index to highlight (1-based).
-- @tparam[opt] table opts.highlight_attr Text attributes for highlighted lines (defaults to { reverse = true }).
-- @treturn TextPanel A new TextPanel instance.
-- @usage
--   local TextPanel = require("terminal.ui.panel.text")
--   local panel = TextPanel {
--     lines = {"Line 1", "Line 2", "Line 3"},
--     scroll_step = 2,
--     initial_position = 1,
--     text_attr = { fg = "green", brightness = "bright" },
--     highlight = 2,
--     highlight_attr = { fg = "red", bg = "yellow" },
--   }
--   panel:set_position(5)  -- Go to line 5
--   panel:scroll_down()  -- Scroll down by scroll_step
function TextPanel:init(opts)
  opts = opts or {}

  -- Extract text panel specific options
  local lines = opts.lines or {}
  local scroll_step = opts.scroll_step or 1
  local initial_position = opts.initial_position or 1
  local text_attr = opts.text_attr
  local auto_render = not not opts.auto_render -- force to boolean
  local max_lines = opts.max_lines
  local line_formatter = opts.line_formatter or self.format_line_truncate
  local highlight = opts.highlight
  local highlight_attr = opts.highlight_attr or { reverse = true }

  -- Remove text panel specific options from opts to avoid conflicts with Panel
  opts.lines = nil
  opts.scroll_step = nil
  opts.initial_position = nil
  opts.text_attr = nil
  opts.auto_render = nil
  opts.max_lines = nil
  opts.line_formatter = nil
  opts.highlight = nil
  opts.highlight_attr = nil

  -- Provide content callback for parent constructor
  opts.content = function(self)
    self:_draw_text()
  end

  -- Call parent constructor
  Panel.init(self, opts)

  -- Set text panel specific properties
  self.scroll_step = scroll_step
  self.text_attr = text_attr
  self.max_lines = max_lines
  self.line_formatter = line_formatter
  self.highlight_attr = highlight_attr
  self.line_refs = {} -- key = formatted-line index, value = source line index

  self.auto_render = false -- set to false initially to prevent render during initialization
  self.formatted_lines = nil
  self:set_lines(lines)
  self:set_position(initial_position)
  self:set_highlight(highlight)
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
    local is_highlighted = self.highlight and self.highlight == self.line_refs[i]

    -- Add cursor positioning to sequence
    seq[n] = terminal.cursor.position.set_seq(line_row, self.inner_col)
    n = n + 1

    -- Add highlight attributes if this line should be highlighted
    if is_highlighted then
      seq[n] = terminal.text.stack.push_seq(self.highlight_attr)
      n = n + 1
    end

    -- Add the text content
    seq[n] = self.formatted_lines[i]
    n = n + 1

    -- Pop highlight attributes if they were pushed
    if is_highlighted then
      seq[n] = terminal.text.stack.pop_seq()
      n = n + 1
    end
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



--- Format a line by truncating/padding it to fit the available width.
-- Returned lines must be padded with spaces to prevent having to clear lines.
-- @tparam string line The line text to format.
-- @tparam number max_width Maximum width in display columns.
-- @treturn table Array of formatted lines
function TextPanel:format_line_truncate(line, max_width)
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


--- Format a line by wrapping it to fit the available width.
-- @tparam string line The line text to format.
-- @tparam number max_width Maximum width in display columns.
-- @treturn table Array of formatted lines
function TextPanel:format_line_wrap(line, max_width)
  local line = line or ""

  local el = EditLine(line)
  local lines = el:format {
    width = max_width,
    wordwrap = false,
    pad = true,
    no_new_cursor_line = true,
  }

  -- force string results
  for i, line in ipairs(lines) do
    lines[i] = tostring(line)
  end

  return lines
end


--- Format a line by word-wrapping it to fit the available width.
-- @tparam string line The line text to format.
-- @tparam number max_width Maximum width in display columns.
-- @treturn table Array of formatted lines
function TextPanel:format_line_wordwrap(line, max_width)
  local el = EditLine(line)
  local lines = el:format {
    width = max_width,
    wordwrap = true,
    pad = true,
    no_new_cursor_line = true,
  }

  -- force string results
  for i, line in ipairs(lines) do
    lines[i] = tostring(line)
  end

  return lines
end


-- Internal: rebuild formatted_lines from source lines for current width
function TextPanel:_rebuild_formatted_lines()
  assert(self.inner_width, "inner_width is not set, cannot rebuild formatted_lines, call calculate_layout first")
  local width = self.inner_width
  local out = {}
  local line_refs = {}
  for i, line in ipairs(self.lines) do
    for _, formatted_line in ipairs(self:line_formatter(line, width)) do
      table.insert(out, formatted_line)
      table.insert(line_refs, i)
    end
  end
  self.formatted_lines = out
  self.line_refs = line_refs

  -- ensure the position is valid since number of lines might have changed, but
  -- we don't want to render in the middle of this process
  local auto_render = self.auto_render
  self.auto_render = false
  self:set_position(self.position)
  self.auto_render = auto_render
end



--- Set the viewport position to a specific line.
-- If the position is out of bounds, it will be corrected to be within bounds.
-- @tparam number position The line position to go to (1-based).
-- @return nothing
function TextPanel:set_position(position)
  if not self.inner_width then
    -- there is no inner-width set, so we cannot calculate the position,
    -- since any wrapping lines can be 1 or more lines, hence unknown total size.
    -- Just accept position, when reformatting lines in rebuild_formatted_lines we
    -- will call set_position again, and by then we can validate the position.
    -- So for now just accept the value set.
    self.position = position -- there is no width, so auto_render is irrelevant here (see below)
    return
  end

  local old_position = self.position

  if not self.formatted_lines then
    -- width is known, but we haven't formatted yet. Just format
    -- since formatting will call set_position again with auto-render disabled, so
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
  self:set_position(self.position - self.scroll_step)
end



--- Scroll down by scroll_step lines.
-- @return nothing
function TextPanel:scroll_down()
  self:set_position(self.position + self.scroll_step)
end



--- Scroll up by one page (inner_height lines).
-- @return nothing
function TextPanel:page_up()
  if not self.inner_height then
    return
  end
  self:set_position(self.position - self.inner_height)
end



--- Scroll down by one page (inner_height lines).
-- @return nothing
function TextPanel:page_down()
  if not self.inner_height then
    return
  end
  self:set_position(self.position + self.inner_height)
end



--- Get the current scroll position.
-- @treturn number The current line position (1-based).
function TextPanel:get_position()
  return self.position
end



--- Get the source-line index from the display-line index.
-- @tparam number display_line_index The display-line index to get the source-line index for.
-- @treturn number The source-line index, or nil if the display-line index is out of bounds.
function TextPanel:get_source_line_index(display_line_index)
  return self.line_refs[display_line_index]
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
-- This will reset position to 1, and clear highlighting.
-- @tparam table lines Array of text lines.
-- @return nothing
function TextPanel:set_lines(lines)
  if self.max_lines and #lines > self.max_lines then
    error("max_lines is set and number of lines is greater than max_lines")
  end

  self.lines = lines or {}
  self.highlight = nil
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

  -- Enforce max_lines limit if set
  local must_redraw = false
  local source_lines_dropped = 0
  while self.max_lines and #self.lines > self.max_lines do
    local drop_line = table.remove(self.lines, 1)
    source_lines_dropped = source_lines_dropped + 1
    if self.formatted_lines then
      -- how many formatted lines do we drop from this 1 input line?
      -- format line again to find out how many lines it would take up
      local drop_lines = #self:line_formatter(drop_line, self.inner_width)
      for i = 1, drop_lines do
        table.remove(self.formatted_lines, 1)
        table.remove(self.line_refs, 1)
      end
      self.position = self.position - drop_lines
      if self.position < 1 then
        self.position = 1
        must_redraw = true
      end
    end
  end

  -- Adjust highlight index when lines are removed from the beginning
  if self.highlight then
    self.highlight = self.highlight - source_lines_dropped
    if self.highlight < 1 then
      self.highlight = 1
    end
  end

  if source_lines_dropped > 0 then
    for i, ref in ipairs(self.line_refs) do
      self.line_refs[i] = ref - source_lines_dropped
    end
  end

  local width = self.inner_width
  local formatted_lines = self.formatted_lines
  local ref = #self.lines

  if width and formatted_lines then
    local old_line_count = #formatted_lines
    for _, formatted_line in ipairs(self:line_formatter(line, width)) do
      table.insert(formatted_lines, formatted_line)
      table.insert(self.line_refs, ref)
    end

    if self.auto_render then
      -- only write the new lines if they are inside the viewport
      local lastline_displayed = self.position + self.inner_height - 1
      if must_redraw or lastline_displayed > old_line_count then
        self:render()
      end
    end
  end
end


--- Set the line formatter function.
-- Must conform to the `line_formatter` function signature;
-- `array_formatted_lines = function(text_panel_instance, line, max_width)`.
-- The formatted lines must be full width, padded with spaces where necessary, to ensure
-- that any previous content is overwritten.
--
-- This class comes with 3 formatters:
--
-- - `TextPanel.format_line_truncate` - truncates long lines (default)
-- - `TextPanel.format_line_wrap` - wraps lines to fit the available width
-- - `TextPanel.format_line_wordwrap` - word-wraps lines to fit the available width
-- @tparam function formatter_func The formatter function to use.
-- @return nothing
function TextPanel:set_line_formatter(formatter_func)
  if self.line_formatter ~= formatter_func then
    self.line_formatter = formatter_func
    self.formatted_lines = nil
    if self.auto_render then
      self:render()
    end
  end
end



--- Set the highlight for a specific source line.
-- @tparam number|nil source_line_idx The source line index to highlight, or nil to remove highlight.
-- @tparam[opt=false] boolean jump Whether to adjust viewport to show the highlighted line.
-- @return nothing
function TextPanel:set_highlight(source_line_idx, jump)
  -- Validate source_line_idx
  if source_line_idx then
    if source_line_idx < 1 or source_line_idx > #self.lines then
      source_line_idx = nil -- Out of bounds, remove highlight
    end
  end

  if self.highlight ~= source_line_idx then
    self.highlight = source_line_idx

    -- Adjust viewport if jump is requested and we have a valid highlight
    if jump and source_line_idx and self.inner_height then
      self:_jump_to_highlight()
    end

    if self.auto_render then
      -- TODO: rewrite only what is visible, no need to rerender everything
      self:render()
    end
  end
end



--- Private method to adjust viewport to show the highlighted line.
-- @return nothing
function TextPanel:_jump_to_highlight()
  if not self.highlight or not self.inner_height then
    return
  end

  -- Ensure formatted_lines are available
  if not self.formatted_lines then
    self:_rebuild_formatted_lines()
  end

  -- Find the first and last formatted line indices for the highlighted source line
  local first_formatted_line = nil
  local last_formatted_line = nil

  for i = 1, #self.formatted_lines do
    if self.line_refs[i] == self.highlight then
      if not first_formatted_line then
        first_formatted_line = i
      end
      last_formatted_line = i
    end
  end

  if not first_formatted_line then
    return -- Highlighted line not found in formatted lines
  end

  -- Calculate the current viewport bounds
  local current_start = self.position
  local current_end = current_start + self.inner_height - 1

  -- Check if the highlighted line is already fully visible
  if first_formatted_line >= current_start and last_formatted_line <= current_end then
    return -- Already fully visible, no need to adjust
  end

  -- Determine the best position to show the highlighted line
  local new_position

  if first_formatted_line < current_start then
    -- Highlighted line is above viewport, position it at the top
    new_position = first_formatted_line
  else
    -- Highlighted line is below viewport, position it at the bottom
    new_position = last_formatted_line - self.inner_height + 1
  end

  -- Ensure the new position is valid
  local max_position = math.max(1, #self.formatted_lines - self.inner_height + 1)
  new_position = math.max(1, math.min(new_position, max_position))

  -- Update the position
  self.position = new_position
end



--- Get the highlighted source line index.
-- @treturn number|nil The highlighted source line index, or nil if no highlight is set.
function TextPanel:get_highlight()
  return self.highlight
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
