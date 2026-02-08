-- Compare this to examples/prompt.lua to see how to make it behave asynchronously
-- by integrating with the Copas coroutine scheduler

local t = require("terminal")
local Prompt = require("terminal.cli.prompt")
local copas = require("copas")


local terminal_opts = {
  sleep = copas.pause, -- use copas pause for sleep to allow other coroutines to run
  disable_sigint = true, -- disable ctrl-c signal handling (so it can be handled as a cancellation key in the prompt)
}


local pr = Prompt {
  prompt = "Enter something: ",
  value = "Hello, 你-好 World 🚀!",
  max_length = 62,
  position = 10,
  cancellable = true,
  text_attr = { brightness = "high" },
  wordwrap = true,
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
  t.text.stack.push { brightness = "low" }
  print("Time is ticking in the top-right corner!")
  local result, err = pr()
  if result then
    print("Result (string): '" .. result .. "'")
    print("Result (bytes):", (result or ""):byte(1, -1))
  else
    print("Status: " .. (err or "nil"))
  end

  clock:cancel() -- stop the timer
end)


local main = t.initwrap(copas.loop, terminal_opts)

main()
