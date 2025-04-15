-- experimental/luarox.lua
-- Minimal LuaRocks wrapper prototype using only terminal.cli.select

local t = require("terminal")
local Select = require("terminal.cli.select")
local draw = t.draw
local print = t.output.print

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

-- Reads a line in blocking + canonical mode temporarily
local function read_blocking_line(prompt)
  t.shutdown()               -- exit raw mode (back to normal terminal)
  io.write(prompt or "> ")   -- print prompt
  io.flush()
  local line = io.read("*l") -- read user input (blocking)
  t.initialize()             -- re-enable raw mode for terminal.lua
  io.flush()
  return line
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
    print()

    if selection == "luarocks list" then
      run_shell_command("luarocks list")

    elseif selection == "luarocks install" then
      local rock = read_blocking_line("Enter rock to install: ")
      if rock and rock ~= "" then
        run_shell_command("luarocks install " .. rock .. " --local")
      else
        print("No rock entered. Aborting.")
      end

    elseif selection == "luarocks search" then
      local term = read_blocking_line("Enter term to search: ")
      if term and term ~= "" then
        run_shell_command("luarocks search " .. term)
      else
        print("No search term entered.")
      end
    end
  end
end

t.initwrap(main)()
