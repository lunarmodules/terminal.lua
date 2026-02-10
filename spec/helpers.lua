--- Test helper for Busted specs: load and unload the terminal library (and LuaSystem)
-- for test isolation. Cleans from `package.loaded`: `"terminal"`, any `"terminal.*"`,
-- and `"system"`. Intended for use from Busted setup/teardown or before_each/after_each.
-- This module does not require terminal or system at load time.
-- @module spec.helpers



local M = {}



-- Remove terminal and LuaSystem from package.loaded and run GC.
-- Used internally by load() and unload(). Cleans `"terminal"`, `"system"`, and
-- any key starting with `"terminal."`.
local function clean()
  for key, _ in pairs(package.loaded) do
    if key == "terminal" or
       key == "system" or
       (type(key) == "string" and key:sub(1, 11) == "terminal.") then
      package.loaded[key] = nil
    end
  end
  -- call twice to ensure finalization is complete
  collectgarbage()
  collectgarbage()
end



--- Load the main terminal module after cleaning package.loaded.
-- Cleans terminal and LuaSystem from `package.loaded`, then requires the main
-- `terminal` module and returns it. Call from Busted setup or before_each.
-- @treturn table the main terminal module
function M.load()
  clean()
  return require("terminal")
end



--- Remove terminal and LuaSystem from package.loaded.
-- Does not require terminal. Call from Busted teardown or after_each so the
-- next load() gets a fresh terminal. Idempotent.
function M.unload()
  clean()
end



return M
