--- Example demonstrating all four cli.* widgets in a single flow.
--
-- A small "project setup wizard" that collects settings step by step using
-- Select, MultiSelect, Prompt, and Confirm. Any step can be cancelled with
-- Esc or Ctrl-C; cancelling anywhere aborts the whole wizard.

local t = require("terminal")
local Select      = require("terminal.cli.select")
local MultiSelect = require("terminal.cli.multiselect")
local Prompt      = require("terminal.cli.prompt")
local Confirm     = require("terminal.cli.confirm")


local function main()
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("Project Setup Wizard")
  t.text.pop()
  t.output.print()

  -- step 1: select a language (cli.Select)
  local idx, lang = Select {
    prompt = "Pick a language:",
    choices = { "Lua", "Python", "JavaScript", "Go" },
    cancellable = true,
    clear = false,
  }()

  if not idx then
    t.output.print("Setup cancelled.")
    return
  end

  -- step 2: enable optional features (cli.MultiSelect)
  local features = {
    { label = "Unit tests",     key = "tests",     value = true  },
    { label = "CI workflow",    key = "ci",        value = true  },
    { label = "Docker support", key = "docker",    value = false },
    { label = "Documentation",  key = "docs",      value = false },
    { label = "Changelog",      key = "changelog", value = false },
  }

  local selected_features = MultiSelect {
    prompt = "Enable features:",
    choices = features,
    cancellable = true,
    clear = false,
  }()

  if not selected_features then
    t.output.print("Setup cancelled.")
    return
  end

  -- step 3: enter a project name (cli.Prompt)
  t.output.print()
  local name = Prompt {
    prompt = "Project name: ",
    value = "my-project",
    max_length = 40,
    cancellable = true,
  }()

  if not name then
    t.output.print("Setup cancelled.")
    return
  end

  -- step 4: confirm before creating (cli.Confirm)
  -- This uses predefined response-sets and predefined answers.
  t.output.print()
  local answer = Confirm {
    prompt = "Create the project?",
    responses = Confirm.sets.yes_no,
    default = Confirm.ids.yes,
    cancellable = true,
  }()

  if answer ~= Confirm.ids.yes then
    t.output.print("Aborted.")
    return
  end

  -- summary
  t.output.print()
  t.text.push { fg = "green", brightness = "high" }
  t.output.print("Project created!")
  t.text.pop()

  t.text.push { brightness = "dim" }
  t.output.write("  Language: ")
  t.text.pop()
  t.output.print(lang)

  t.text.push { brightness = "dim" }
  t.output.write("  Name:     ")
  t.text.pop()
  t.output.print(name)

  t.text.push { brightness = "dim" }
  t.output.print("  Features:")
  t.text.pop()
  for key, enabled in pairs(selected_features) do
    if enabled then
      t.output.print("    + " .. key)
    end
  end

  t.output.print()
end


t.initwrap(main, {
  disable_sigint = true,
})()
