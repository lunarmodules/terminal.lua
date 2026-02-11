--- Test helper for Busted specs: load and unload the terminal library (and LuaSystem)
-- for test isolation. Cleans from `package.loaded`: `"terminal"`, any `"terminal.*"`,
-- and `"system"`. Intended for use from Busted setup/teardown or before_each/after_each.
-- This module does not require terminal or system at load time.
-- @module spec.helpers



local M = {}

local terminal  -- to hold the terminal module if loaded
local system -- to hold the system module if loaded



local get_config do
  -- this config table holds config values as configured for the mock functions.
  -- the key is the terminal module-table, the value a hash-table of config values.
  -- Because it is set to weak-key, the table is only kept alive if the terminal module
  -- is still in use, aftre a reload it will be a fresh copy again.
  local config = setmetatable({}, { __mode = "k" })


  -- returns the mock config for the current modules (system and terminal)
  -- every mock function should call this to ensure we run the asserts.
  function get_config()
    assert(terminal, "modules not loaded yet, first call 'load()'")

    local cfg = config[terminal]
    if not cfg then
      cfg = setmetatable({}, {
        __index = function(self, key)
          -- the top-level is an "auto-table", if there is no key, we create and return an empty table.
          -- so we can reduce extensive checking elsewhere in this module
          self[key] = {}
          return self[key]
        end
      })
      config[terminal] = cfg
    end
    return cfg
  end
end



-- ====================================================================================================
-- Mock functions for system and terminal
-- ====================================================================================================



-- Sets the terminal size.
-- @tparam number rows number of rows
-- @tparam number columns number of columns
function M.set_termsize(rows, columns)
  assert(type(rows) == "number", "rows must be a number, got " .. type(rows))
  assert(type(columns) == "number", "columns must be a number, got " .. type(columns))

  get_config().termsize = {
    rows = rows,
    columns = columns,
  }
end



--- Gets the terminal size.
-- This is the mock function for `system.termsize()`.
-- If the terminal size wasn't set yet, returns 25x80.
-- @treturn number rows number of rows
-- @treturn number columns number of columns
function M.get_termsize()
  local cfg = get_config()
  return cfg.termsize.rows or 25, cfg.termsize.columns or 80
end



-- ====================================================================================================
-- (Un)loading and patching system and terminal to enable mocks
-- ====================================================================================================


-- Patches system to enable mocking
local function patch_system()
  system.termsize = M.get_termsize
end



-- Patches terminal to enable mocking
local function patch_terminal()
end



--- Load the main terminal and system modules after cleaning package.loaded.
-- Cleans terminal and LuaSystem from `package.loaded`, then requires the main
-- `terminal` module. Will patch both libraries to enable the mocks.
-- Call from Busted setup or before_each.
-- @treturn table the main terminal module
function M.load()
  M.unload()

  system = require("system")
  patch_system()

  terminal = require("terminal")
  patch_terminal()

  return terminal
end



--- Remove terminal and LuaSystem from package.loaded.
-- Does not load them again. Call from Busted teardown or after_each so the
-- next load() gets a fresh terminal. Idempotent.
function M.unload()
  terminal = nil
  system = nil
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



return M
