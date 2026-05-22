--- Example demonstrating the cli.MultiSelect widget.
--
-- Presents a list of project features with some recommended defaults
-- pre-checked, then prints a summary of the chosen configuration.

local t = require("terminal")
local MultiSelect = require("terminal.cli.multiselect")



local function main()
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("cli.MultiSelect demo")
  t.text.pop()
  t.output.print()


  local features = {
    { label = "Unit tests",       key = "tests",     value = true  },
    { label = "CI workflow",      key = "ci",        value = true  },
    { label = "Docker support",   key = "docker",    value = false },
    { label = "Type annotations", key = "types",     value = false },
    { label = "Documentation",    key = "docs",      value = false },
    { label = "Changelog",        key = "changelog", value = false },
  }

  local ms = MultiSelect {
    prompt = "Enable features:",
    choices = features,
    cancellable = true,
  }
  local result, err = ms()

  if not result then
    t.output.print(result, err)
    return
  end


  -- summary
  t.output.print()
  t.text.push { fg = "green", brightness = "high" }
  t.output.print("Configuration ready!")
  t.text.pop()

  t.output.print("result = {")
  for key, value in pairs(result) do
    t.output.print('    "' .. key .. '" = ' .. tostring(value) .. ",")
  end
  t.output.print("}")

  t.output.print()
  ms:print_selection()
end



t.initwrap(main, {
  disable_sigint = true, -- allow ctrl-c as cancellation in widgets
})()
