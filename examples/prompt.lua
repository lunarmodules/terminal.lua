local t = require("terminal")
local Prompt = require("terminal.cli.prompt")


local terminal_opts = {
  -- use all defaults
}


local pr = Prompt {
  prompt = "Enter something: ",
  value = "Hello, 你-好 World 🚀!",
  max_length = 162,
  position = 10,
  cancellable = true,
  text_attr = { brightness = "high" },
  wordwrap = true,
}


local main = t.initwrap(function()
  t.text.stack.push { brightness = "low" }
  local result, status = pr()
  if result then
    print("Result (string): '" .. result .. "'")
    print("Result (bytes):", (result or ""):byte(1, -1))
  else
    print("Status: " .. (status or "nil"))
  end
end, terminal_opts)


main()
