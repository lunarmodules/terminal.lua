--- A confirmation widget for CLI tools.
--
-- Displays a prompt with a list of labelled responses styled as a `cli.Select` menu.
-- The user navigates with arrow keys or typing, and confirms with Enter. Optionally the widget
-- can be cancelled with `<esc>` or `<ctrl+c>`.
--
-- Each response entry is a table `{ label = string, id = any, cancel = bool? }`.
-- When `id` is omitted it defaults to `label`. Marking an entry with `cancel = true`
-- means pressing Escape selects that entry instead of returning `nil, "cancelled"`.
--
-- NOTE: you MUST call `terminal.initialize` before calling this widget's `:run()` method.
--
-- Example using a pre-defined set of responses:
--
--     local Confirm = require("terminal.cli.confirm")
--
--     local widget = Confirm{
--       prompt = "Delete this file?",
--       responses = Confirm.sets.yes_no_cancel,
--       default = Confirm.ids.no,
--     }
--
--     local result = widget()   -- invokes the 'run' method
--     if result == Confirm.ids.yes then
--       -- proceed
--     end
--
-- Example using a custom set of responses:
--
--     local Confirm = require("terminal.cli.confirm")
--
--     local widget = Confirm{
--       prompt = "Choose an option:",
--       responses = {
--         { label = "Option 1", id = "opt1" },
--         { label = "Option 2", id = "opt2", cancel = true },
--       },
--       default = "opt2",
--     }
--
--     local result, err = widget:run()
-- @classmod cli.Confirm

local Select = require("terminal.cli.select")
local utils = require("terminal.utils")

local Confirm = utils.class()



--- Response ID constants. Plain strings used as `id` fields in the preset `sets`.
-- Useful for comparing the return value of `run()` without hardcoding strings.
-- @field ok `"ok"`
-- @field cancel `"cancel"`
-- @field abort `"abort"`
-- @field retry `"retry"`
-- @field ignore `"ignore"`
-- @field yes `"yes"`
-- @field no `"no"`
-- @field try_again `"try_again"`
-- @field continue `"continue"`
-- @table Confirm.ids
Confirm.ids = utils.make_lookup("response id", {
  ok        = "ok",
  cancel    = "cancel",
  abort     = "abort",
  retry     = "retry",
  ignore    = "ignore",
  yes       = "yes",
  no        = "no",
  try_again = "try_again",
  continue  = "continue",
})


--- Preset response sets. Each is an array, where the values are has tables; `{label, id, cancel?}`.
-- These are ready to pass as `opts.responses`, as the most common confirmations.
-- @field ok Single OK response.
-- @field ok_cancel OK and Cancel responses.
-- @field abort_retry_ignore Abort (cancel), Retry, and Ignore responses.
-- @field yes_no_cancel Yes, No, and Cancel responses.
-- @field yes_no Yes and No responses.
-- @field retry_cancel Retry and Cancel responses.
-- @field cancel_try_continue Cancel, Try Again, and Continue responses.
-- @table Confirm.sets
local ids = Confirm.ids
Confirm.sets = utils.make_lookup("response set", {
  ok = {
    { label = "OK", id = ids.ok },
  },
  ok_cancel = {
    { label = "OK",     id = ids.ok },
    { label = "Cancel", id = ids.cancel, cancel = true },
  },
  abort_retry_ignore = {
    { label = "Abort",  id = ids.abort, cancel = true },
    { label = "Retry",  id = ids.retry },
    { label = "Ignore", id = ids.ignore },
  },
  yes_no_cancel = {
    { label = "Yes",    id = ids.yes },
    { label = "No",     id = ids.no },
    { label = "Cancel", id = ids.cancel, cancel = true },
  },
  yes_no = {
    { label = "Yes", id = ids.yes },
    { label = "No",  id = ids.no },
  },
  retry_cancel = {
    { label = "Retry",  id = ids.retry },
    { label = "Cancel", id = ids.cancel, cancel = true },
  },
  cancel_try_continue = {
    { label = "Cancel",    id = ids.cancel,    cancel = true },
    { label = "Try Again", id = ids.try_again },
    { label = "Continue",  id = ids.continue },
  },
})



--- Create a new Confirm instance.
-- @tparam table opts Options for the Confirm widget.
-- @tparam string opts.prompt The question to display.
-- @tparam[opt] table opts.responses List of response entry tables. Each entry must have
-- a `label` (string) and may have an `id` (any; defaults to `label`) and
-- `cancel` (bool; marks the entry selected when Escape is pressed).
-- Defaults to `Confirm.sets.ok`.
-- @tparam[opt] any opts.default The `id` of the response to pre-select. Defaults to the id of the first entry.
-- @tparam[opt] boolean opts.cancellable Whether the widget can be cancelled by pressing
-- `<esc>` or `<ctrl+c>`. Defaults to `true` when a response has `cancel = true`,
-- `false` otherwise.
-- @tparam[opt=false] boolean opts.clear When `false` (default), replaces the widget with
-- a one-line summary on completion. When `true`, clears everything.
-- @treturn Confirm A new Confirm instance.
-- @name cli.Confirm
function Confirm:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(type(opts.prompt) == "string", "prompt must be a string")

  local responses = opts.responses or Confirm.sets.ok
  assert(type(responses) == "table" and #responses > 0, "responses must be a non-empty list")

  local cancel_idx
  local choices = {}
  for i, entry in ipairs(responses) do
    assert(type(entry) == "table", "each response must be a table")
    assert(type(entry.label) == "string", "each response must have a string label")
    choices[i] = entry.label
    if entry.cancel then
      assert(not cancel_idx, "only one response can be marked as cancel")
      cancel_idx = i
    end
  end

  local default_idx = 1
  local default_value
  if opts.default ~= nil then
    for i, entry in ipairs(responses) do
      local v = entry.id
      if v == nil then v = entry.label end
      if v == opts.default then
        default_idx = i
        default_value = v
        break
      end
    end
    assert(default_value ~= nil, "default value not found in responses")
  else
    local first = responses[1]
    default_value = first.id
    if default_value == nil then default_value = first.label end
  end

  self.prompt = opts.prompt
  self.responses = responses
  self.default = default_value
  self.cancel_idx = cancel_idx
  self.cancellable = (cancel_idx     and (opts.cancellable ~= false))
                  or (not cancel_idx and (opts.cancellable == true))
  self.clear = not not opts.clear

  self._select = Select{
    prompt = self.prompt,
    choices = choices,
    default = default_idx,
    cancellable = self.cancellable,
    clear = true,
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



--- Prints a one-line summary of the prompt and selected response.
function Confirm:print_selection()
  self._select:print_selection()
end



--- Executes the widget.
-- On completion, replaces the interactive widget with a one-line summary unless `clear` was set.
-- @treturn[1] any The `id` of the selected response entry (defaults to its `label` when unset).
-- @treturn[2] nil On success.
-- @treturn[2] string Error string `"cancelled"` if cancelled and no response has `cancel = true`.
function Confirm:run()
  local idx, err = self._select:run()

  if not idx then
    if err == "cancelled" and self.cancel_idx then
      -- convert the 'cancelled' error into the cancel options response
      idx = self.cancel_idx
      self._select:set_selection(idx)
    else
      return nil, err
    end
  end

  if not self.clear then
    self:print_selection()
  end

  local entry = self.responses[idx]
  return entry.id == nil and entry.label or entry.id
end



return Confirm
