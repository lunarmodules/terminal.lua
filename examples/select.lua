--- Example demonstrating the cli.Select and cli.Prompt widgets together.
--
-- This example builds a small interactive setup wizard that uses Select
-- for menu choices and Prompt for text input, showing how to combine
-- CLI widgets in a sequential flow with text attributes for feedback.

local t = require("terminal")
local Select = require("terminal.cli.select")
local Prompt = require("terminal.cli.prompt")


local function main()
  -- greeting
  t.text.push { fg = "cyan", brightness = "high" }
  t.output.print("Welcome to the project setup wizard!")
  t.text.pop()
  t.output.print()

  -- step 1: select a language
  local idx, lang = Select {
    prompt = "Pick a language:",
    choices = {
      "Lua",
      "Python",
      "JavaScript",
      "Go",
    },
    cancellable = true,
    clear = true,
  }()

  if not idx then
    t.output.print("Setup cancelled.")
    return
  end

  -- step 2: select a license
  local _, license = Select {
    prompt = "Choose a license:",
    choices = {
      "MIT",
      "Apache-2.0",
      "GPL-3.0",
      "BSD-2-Clause",
    },
    cancellable = true,
    clear = true,
  }()

  if not license then
    t.output.print("Setup cancelled.")
    return
  end

  -- step 3: text input for project name
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

  -- summary
  t.output.print()
  t.text.push { fg = "green", brightness = "high" }
  t.output.print("Setup complete!")
  t.text.pop()

  t.text.push { brightness = "dim" }
  t.output.write("  Language: ")
  t.text.pop()
  t.output.print(lang)

  t.text.push { brightness = "dim" }
  t.output.write("  License:  ")
  t.text.pop()
  t.output.print(license)

  t.text.push { brightness = "dim" }
  t.output.write("  Name:     ")
  t.text.pop()
  t.output.print(name)

  t.output.print()
end


t.initwrap(main, {
  disable_sigint = true, -- allow ctrl-c as cancellation in widgets
})()
