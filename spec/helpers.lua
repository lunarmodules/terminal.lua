--- Test helper for Busted specs: load and unload the terminal library (and LuaSystem)
-- for test isolation. Cleans from `package.loaded`: `"terminal"`, any `"terminal.*"`,
-- and `"system"`. Intended for use from Busted setup/teardown or before_each/after_each.
-- This module does not require terminal or system at load time.
-- @module spec.helpers



local M = {}

local terminal  -- to hold the terminal module if loaded
local system -- to hold the system module if loaded



-- nil safe versions of pack and unpack
local pack = require("pl.utils").pack
local unpack = require("pl.utils").unpack



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



--- Reads a single byute from the keyboard buffer, which is mocked.
-- This is the mock for `system._readkey()`
-- @treturn number the byte read from the keyboard buffer, or nil if the buffer is empty
function M._readkey()
  local buffer = get_config().keyboardbuffer
  local entry = table.remove(buffer, 1) or {}
  return unpack(entry)
end



--- Pushes input into the keyboard buffer mock.
-- @tparam string seq the sequence of input, individual bytes of this string will be returned
-- @tparam string err an eror to return, in this case `seq` MUST be nil.
function M._push_input(seq, err)
  -- TODO: rename this function, remove underscore
  local buffer = get_config().keyboardbuffer

  if type(seq) == "string" then
    assert(err == nil, "error must be nil if seq is a string")
    assert(seq ~= "", "seq must be a non-empty string")
    for i = 1, #seq do
      table.insert(buffer, pack(string.byte(seq, i)))
    end

  elseif seq == nil then
    assert(type(err) == "string", "err must be a string if seq is nil")
    assert(err ~= "", "err must be a non-empty string")
    table.insert(buffer, pack(nil, err))

  else
    error("invalid type for seq, must be a string or nil")
  end
end



-- Gets the output written to the output stream.
-- @treturn string the output written to the output stream, empty string if no output
-- was written yet.
function M.get_output()
  local cfg = get_config()
  if not cfg.output.filename then
    return ""
  end
  return assert(require("pl.utils").readfile(cfg.output.filename))
end



--- Clears the output written to the output stream.
-- and recreates an empty output file.
function M.clear_output()
  local cfg = get_config()

  -- close an existing file
  if cfg.output.filehandle then
    cfg.output.filehandle:close()
    cfg.output.filehandle = nil
  end

  -- remove an existing file, define name if none set yet
  if cfg.output.filename then
    os.remove(cfg.output.filename)
  else
    cfg.output.filename = require("pl.path").tmpname()
  end

  -- reopen file, and set it as the output stream
  cfg.output.filehandle = assert(io.open(cfg.output.filename, "wb"))
  terminal.output.set_stream(cfg.output.filehandle)
end



-- ====================================================================================================
-- (Un)loading and patching system and terminal to enable mocks
-- ====================================================================================================


-- Patches system to enable mocking
local function patch_system()
  system.termsize = M.get_termsize
  system._readkey = M._readkey
end



-- Patches terminal to enable mocking
local function patch_terminal()
  M.clear_output()

  -- disable changing the output stream
  local set_stream = terminal.output.set_stream
  terminal.output.set_stream = function(filehandle)
    local cfg = get_config() -- the upvalue cfg might be outdated, need to get the latest one
    if filehandle ~= cfg.output.filehandle then
      return true
    end
    -- only set it if it matches the mocked filehandle
    return set_stream(filehandle)
  end
end



-- Cleanup a config entry
local function clean_config()
  local cfg = get_config()

  -- cleanup output files
  if cfg.output.filehandle then
    cfg.output.filehandle:close()
    cfg.output.filehandle = nil
  end
  if cfg.output.filename then
    os.remove(cfg.output.filename)
    cfg.output.filename = nil
  end
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

  _G._TEST = true  -- some modules export some private internals for testing
  terminal = require("terminal")
  patch_terminal()

  return terminal
end



--- Remove terminal and LuaSystem from package.loaded.
-- Does not load them again. Call from Busted teardown or after_each so the
-- next load() gets a fresh terminal. Idempotent.
function M.unload()
  -- clean up package.loaded
  for key, _ in pairs(package.loaded) do
    if key == "terminal" or
       key == "system" or
       (type(key) == "string" and key:sub(1, 11) == "terminal.") then
      package.loaded[key] = nil
    end
  end
  -- cleanup any dangling stuff
  if terminal then
    clean_config()
  end
  terminal = nil
  system = nil                                                -- luacheck: ignore
  _G._TEST = nil
  -- call twice to ensure finalization is complete
  collectgarbage()
  collectgarbage()
end



return M
