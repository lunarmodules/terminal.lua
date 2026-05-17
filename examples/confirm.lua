--- Example demonstrating the cli.Confirm widget.
--
-- Step 1: pick a response set from a menu.
-- Step 2: run a confirmation widget using that set, then show the result.

local t = require("terminal")
local Select = require("terminal.cli.select")
local Confirm = require("terminal.cli.confirm")



local function main()
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("cli.Confirm demo")
  t.text.pop()



  -- step 1: pick a response set
  local labels = {}
  for name, set in pairs(Confirm.response_sets) do
    labels[#labels + 1] = name
  end

  local choice = Select {
    prompt = "Pick a response set:",
    choices = labels,
    cancellable = true,
    clear = true,
  }
  local idx, err = choice()

  if not idx then
    t.output.print(idx, err)
    return
  end

  choice:print_selection()

  local chosen_set = Confirm.response_sets[labels[idx]]



  -- step 2: run the confirmation widget with the chosen set
  local confirm = Confirm {
    prompt = "Proceed with the operation?",
    responses = chosen_set,
    cancellable = true,
  }
  local result, err = confirm()

  -- show result
  if not result then
    t.output.print("An error was returned: ", result, err)
  end

end


t.initwrap(main, {
  disable_sigint = true, -- allow ctrl-c as cancellation in widgets
})()
