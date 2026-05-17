--- A confirmation widget widget for CLI tools.
--
-- Displays a prompt with a list of labelled responses styled as a `cli.Select` menu.
-- The user navigates with arrow keys and confirms with Enter. Optionally the widget
-- can be cancelled with `<esc>` or `<ctrl+c>`.
--
-- NOTE: you MUST call `terminal.initialize` before calling this widget's `:run()` method.
--
-- *Usage:*
--     local Confirm = require("terminal.cli.confirm")
--
--     local widget = Confirm{
--       prompt = "Delete this file?",
--       responses = Confirm.response_sets.yes_no_cancel,
--       default = Confirm.response_ids.no,
--       cancellable = true,
--     }
--
--     local result = widget()   -- invokes the 'run' method
--     if result == Confirm.response_ids.yes then
--       -- proceed
--     end
-- @classmod cli.Confirm

local t = require("terminal")
local Select = require("terminal.cli.select")
local utils = require("terminal.utils")

local Confirm = utils.class()

--- Response set constants. A reference to `utils.response_sets`.
-- @table Confirm.response_sets
Confirm.response_sets = utils.response_sets

--- Response ID constants. A reference to `utils.response_ids`.
-- @table Confirm.response_ids
Confirm.response_ids = utils.response_ids

--- Response label constants. A reference to `utils.response_labels`.
-- @table Confirm.response_labels
Confirm.response_labels = utils.response_labels


-- Summary line symbol (filled counterpart to Select's open diamond prompt symbol).
local filled_diamond = "◆ "



--- Create a new Confirm instance.
-- @tparam table opts Options for the Confirm widget.
-- @tparam string opts.prompt The question to display.
-- @tparam[opt=ok] table opts.responses a response ID set from `utils.response_sets`.
-- @tparam[opt] string opts.default Response ID from `utils.response_ids` to pre-select. Defaults to the first response in the list.
-- @tparam[opt] boolean opts.cancellable Whether the widget can be cancelled by pressing `<esc>` or `<ctrl+c>`.
-- Defaults to `true` when `cancel` is in `responses`, `false` otherwise.
-- @tparam[opt=false] boolean opts.clear When `false` (default), replaces the widget with a one-line
-- summary of the prompt and chosen response on completion. When `true`, clears everything.
-- @treturn Confirm A new Confirm instance.
-- @name cli.Confirm
function Confirm:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(type(opts.prompt) == "string", "prompt must be a string")

  local responses = opts.responses or utils.response_sets.ok
  assert(type(responses) == "table" and #responses > 0, "responses must be a non-empty list")
  for _, id in ipairs(responses) do
    local _ = utils.response_ids[id]  -- validates; throws "Invalid response id: ..." if unknown
  end

  local default_id = opts.default or responses[1]
  local _ = utils.response_ids[default_id]  -- validates; throws if unknown

  local default_idx
  local has_cancel = false
  local choices = {}
  for i, id in ipairs(responses) do
    choices[i] = utils.response_labels[id]
    if id == default_id then
      default_idx = i
    end
    if id == utils.response_ids.cancel then
      has_cancel = true
    end
  end
  assert(default_idx, "default '" .. default_id .. "' is not a valid response")

  self.prompt = opts.prompt
  self.responses = responses
  self.default = default_id
  self.has_cancel = has_cancel
  self.cancellable = has_cancel and opts.cancellable ~= false
                  or not has_cancel and not not opts.cancellable
  self.clear = not not opts.clear

  self._select = Select{
    prompt = self.prompt,
    choices = choices,
    default = default_idx,
    cancellable = self.cancellable,
    clear = true,  -- always clear the interactive widget; Confirm handles the summary
  }
end



-- Allow instance to be called directly.
function Confirm:__call()
  return self:run()
end



--- Returns the display height in rows.
-- @treturn number The height of the widget in rows.
function Confirm:height()
  return self._select:height()
end



--- Clears the widget from the screen.
function Confirm:clear_widget()
  return self._select:clear_widget()
end



--- Executes the widget.
-- Initializes the terminal if necessary, and handles cleanup after the widget closes.
-- On completion, replaces the interactive widget with a one-line summary unless `clear` was set.
-- @treturn[1] string The selected response ID (e.g. `utils.response_ids.yes`).
-- @treturn[2] nil On error.
-- @treturn[2] string `"cancelled"` if cancelled without a `cancel` response in the set.
function Confirm:run()
  local idx, err = self._select:run()

  local response
  if not idx then
    if err == "cancelled" and self.has_cancel then
      response = utils.response_ids.cancel
    else
      return nil, err
    end
  else
    response = self.responses[idx]
  end

  if not self.clear then
    t.output.write(
      t.text.push_seq({ fg = "green" }),
      filled_diamond,
      t.text.pop_seq(),
      self.prompt,
      " ",
      t.text.push_seq({ brightness = "dim" }),
      utils.response_labels[response],
      t.text.pop_seq(),
      t.clear.eol_seq(),
      "\n"
    )
  end

  return response
end



return Confirm
