local t = require("terminal")
local Prompt = require("terminal.cli.prompt")
local copas = require("copas")

local terminal_opts = {
  sleep = copas.pause, -- use copas pause for sleep to allow other coroutines to run
}


local pr = Prompt {
  prompt = "Enter something: ",
  value = "Hello, 你-好 World 🚀!",
  max_length = 62,
  position = 2,
  cancellable = true,
}


local clock = copas.timer.new{
  delay = 0.2,
  initial_delay = 0,
  recurring = true,
  callback = function()
    local time = os.date("%H:%M:%S")
    local row = 1
    local _, cols = t.size()
    local col = cols - #time - 1
    t.cursor.position.backup()
    t.cursor.position.set(row, col)
    t.output.print(time)
    t.cursor.position.restore()
  end,
}


copas.addthread(function()
  print("Time is ticking in the top-right corner!")
  local result, status = pr:run()
  if result then
    print("Result (string): '" .. result .. "'")
    print("Result (bytes):", (result or ""):byte(1, -1))
  else
    print("Status: " .. (status or "nil"))
  end

  clock:cancel() -- stop the timer
end)


t.initwrap(copas.loop, terminal_opts)()
