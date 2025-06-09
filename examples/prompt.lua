local t = require("terminal")
local Prompt = require("terminal.cli.prompt")

local pr = Prompt {
  prompt = "Enter something: ",
  value = "Hello, 你-好 World 🚀!",
  max_length = 62,
  position = 2,
  cancellable = true,
}

local result, status = pr:run()

t.initwrap(function ()
  if result then
    print("Result (string): '" .. result .. "'")
    print("Result (bytes):", (result or ""):byte(1, -1))
  else
    print("Status: " .. (status or "nil"))
  end
end, {})()
