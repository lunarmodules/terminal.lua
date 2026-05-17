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
--     local utils = require("terminal.utils")
--
--     local widget = Confirm{
--       prompt = "Delete this file?",
--       responses = utils.response_sets.yes_no_cancel,
--       default = utils.response_ids.no,
--       cancellable = true,
--     }
--
--     local result = widget()   -- invokes the 'run' method
--     if result == utils.response_ids.yes then
--       -- proceed
--     end
-- @classmod cli.Confirm

local Select = require("terminal.cli.select")
local utils = require("terminal.utils")

local Confirm = utils.class()


--- Create a new Confirm instance.
-- @tparam table opts Options for the Confirm widget.
-- @tparam string opts.prompt The question to display.
-- @tparam[opt=ok] table opts.responses a response ID set from `utils.response_sets`.
-- @tparam[opt] string opts.default Response ID from `utils.response_ids` to pre-select. Defaults to the first response in the list.
-- @tparam[opt] boolean opts.cancellable Whether the widget can be cancelled by pressing `<esc>` or `<ctrl+c>`.
-- Defaults to `true` when `cancel` is in `responses`, `false` otherwise.
-- @tparam[opt=false] boolean opts.clear Whether to clear the widget from screen after completion.
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
    clear = self.clear,
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
-- @treturn[1] response_id The selected response ID (e.g. `utils.response_ids.yes`).
-- @treturn[2] nil upon an error
-- @treturn[2] string error message.
function Confirm:run()
  local idx, err = self._select:run()
  if not idx then
    if err == "cancelled" and self.has_cancel then
      return utils.response_ids.cancel
    end
    return nil, err
  end
  return self.responses[idx]
end



return Confirm
