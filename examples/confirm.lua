--- Example demonstrating the cli.Confirm widget.
--
-- Step 1: pick a response set from a menu.
-- Step 2: run a confirmation widget using that set, then show the result.

local t = require("terminal")
local Select = require("terminal.cli.select")
local Confirm = require("terminal.cli.confirm")
local utils = require("terminal.utils")


-- ordered list of sets to present in the menu
local set_choices = {
  { label = "OK",                      set = utils.response_sets.ok },
  { label = "OK / Cancel",             set = utils.response_sets.ok_cancel },
  { label = "Yes / No",                set = utils.response_sets.yes_no },
  { label = "Yes / No / Cancel",       set = utils.response_sets.yes_no_cancel },
  { label = "Retry / Cancel",          set = utils.response_sets.retry_cancel },
  { label = "Abort / Retry / Ignore",  set = utils.response_sets.abort_retry_ignore },
  { label = "Cancel / Try / Continue", set = utils.response_sets.cancel_try_continue },
}


local function main()
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("cli.Confirm demo")
  t.text.pop()
  t.output.print()

  -- step 1: pick a response set
  local labels = {}
  for _, entry in ipairs(set_choices) do
    labels[#labels + 1] = entry.label
  end

  local idx = Select {
    prompt = "Pick a response set:",
    choices = labels,
    cancellable = true,
    clear = true,
  }()

  if not idx then
    t.output.print("Cancelled.")
    return
  end

  local chosen_set = set_choices[idx].set

  -- step 2: run the confirmation widget with the chosen set
  t.output.print()
  local result, err = Confirm {
    prompt = "Proceed with the operation?",
    responses = chosen_set,
    cancellable = true,
  }()

  -- show result
  t.output.print()
  if result then
    t.text.push { fg = "green", brightness = "high" }
    t.output.write("Response: ")
    t.text.pop()
    t.output.print(utils.response_labels[result] .. " (" .. result .. ")")
  else
    t.text.push { fg = "yellow" }
    t.output.print("Cancelled.")
    t.text.pop()
  end

  t.output.print()
end


t.initwrap(main, {
  disable_sigint = true, -- allow ctrl-c as cancellation in widgets
})()
