-- experimental/luarox.lua
-- Minimal LuaRocks wrapper prototype using only terminal.cli.select

local t = require("terminal")
local Select = require("terminal.cli.select")
local draw = t.draw

-- Helper to run shell commands safely
local function run_shell_command(cmd)
  io.flush()
  t.shutdown()
  os.execute(cmd)
  io.write("\nPress Enter to continue...") io.flush()
  io.read("*l")
  t.initialize()
  io.flush()
end

local function main()
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
    selection = tostring(selection)
    if selection == "Exit" then
      print("Goodbye!")
      break
    end

    local _, width = t.size()
    width = width or 80
    draw.line.title(width, "You selected: " .. selection)

    if selection == "luarocks list" then
      run_shell_command("luarocks list")

    elseif selection == "luarocks install" then
      print("You selected install")

    elseif selection == "luarocks search" then
      print("You selected search")
    end
  end
end

t.initwrap(main)()
