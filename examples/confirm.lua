--- Example demonstrating the cli.Confirm widget.
--
-- Step 1: pick a pre-defined response set using a custom Confirm widget.
-- Step 2: run a confirmation widget using that set, then show the result.

local t = require("terminal")
local Confirm = require("terminal.cli.confirm")



local function main()
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("cli.Confirm demo")
  t.text.pop()



  -- step 1: pick a response set via a custom Confirm widget
  local set_names = {}
  for name in pairs(Confirm.sets) do
    set_names[#set_names + 1] = name
  end
  table.sort(set_names)

  local responses = {}
  for _, name in ipairs(set_names) do
    responses[#responses + 1] = { label = name, id = name }
  end

  local choice = Confirm {
    prompt = "Pick a response set:",
    responses = responses,
    cancellable = true,
  }
  local chosen_name, err = choice()

  if not chosen_name then
    t.output.print("cancelled:", err)
    return
  end



  -- step 2: run the confirmation widget with the chosen set
  local confirm = Confirm {
    prompt = "Proceed with the operation?",
    responses = Confirm.sets[chosen_name],
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
