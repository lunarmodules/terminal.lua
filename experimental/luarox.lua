-- experimental/luarox.lua
-- Interactive LuaRocks wrapper prototype using terminal.cli widgets

local Select = require("terminal.cli.select")
local Prompt = require("terminal.cli.prompt")

-- Function to draw divider
local function divider(title)
  print("\n" .. ("-"):rep(40))
  if title then print(title) end
  print(("="):rep(40) .. "\n")
end

-- Main loop
while true do
  local menu = Select{
    prompt = "Select a LuaRocks command:",
    choices = {
      "luarocks install",
      "luarocks list",
      "luarocks search",
      "Exit"
    },
    cancellable = true
  }

  local _, selection = menu()
  if not selection or selection == "Exit" then
    print("Goodbye!")
    break
  end

  divider("You selected: " .. selection)

  if selection == "luarocks list" then
    os.execute("luarocks list")

  elseif selection == "luarocks install" then
    local rock = Prompt{ prompt = "Enter rock to install:" }()
    if rock and rock ~= "" then
      os.execute("luarocks install " .. rock)
    else
      print("No rock entered. Aborting.")
    end

  elseif selection == "luarocks search" then
    local rock = Prompt{ prompt = "Enter rock to search:" }()
    if rock and rock ~= "" then
      os.execute("luarocks search " .. rock)
    else
      print("No rock entered. Aborting.")
    end
  end
end
