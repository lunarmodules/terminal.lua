-- src/terminal/keymap.lua
-- Centralized key mappings for terminal input

local utils = require("terminal.utils")

local raw_map = {
  ["\27[A"] = "up",
  ["k"]     = "up",

  ["\27[B"] = "down",
  ["j"]     = "down",

  ["\r"]    = "enter",
  ["\n"]    = "enter",

  ["\27"]   = "esc",
}

--- Returns forward and reverse key maps, with error throwing on unknowns
-- @treturn table forward map
-- @treturn table reverse map
local function get_keymap(overrides)
  local map = {}
  local reverse = utils.make_lookup("key name", {})

  for k, v in pairs(raw_map) do
    map[k] = v
    reverse[v] = k
  end

  if overrides then
    for k, v in pairs(overrides) do
      map[k] = v
      reverse[v] = k
    end
  end

  return map, reverse
end

return {
  map = raw_map,
  get = get_keymap
}
