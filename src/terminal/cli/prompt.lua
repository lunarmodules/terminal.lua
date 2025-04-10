-- src/terminal/cli/prompt.lua
local t = require("terminal")
local utils = require("terminal.utils")

local Prompt = utils.class()

function Prompt:init(opts)
  self.prompt = opts.prompt or "Enter value:"
end

function Prompt:run()
  t.output.write(self.prompt .. " ")
  return t.input.readansi(math.huge)
end

function Prompt:__call()
  return self:run()
end

return Prompt
