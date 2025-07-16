local t = require("terminal")
local Prompt = require("terminal.cli.prompt")

local pr = Prompt {
  prompt = "Enter something: ",
  value = "Hello, 你-好 World 🚀!",
  position = 2,
  cancellable = true,
}

t.initwrap(function () -- on Windows: wrap for utf8 output
  local result, status = pr:run()
  if result then
    print("Result (string): '" .. result .. "'")
    print("Result (viewpr): '" .. pr.value:viewport_str() .. "'")
    print("Result (width_): '" .. pr.value.olen .. "'")
    print("Result (vwidth): '" .. pr.value.viewport.width .. "'")
  else
    print("Status: " .. (status or "nil"))
  end
end, {})()
