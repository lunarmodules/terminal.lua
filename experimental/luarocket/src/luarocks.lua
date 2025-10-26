local json_encode = require("luarocket.json-encode")
local json_decode = require("cjson.safe").decode
local strwidth = require("terminal.text.width").utf8swidth
local split = require("pl.utils").split
local async = require("copas.async")
local M = {}

local logpanel = nil
local configpanel = nil
local listpanel = nil
local lr_config = nil



function M.set_logpanel(panel)
  logpanel = panel
end


function M.set_configpanel(panel)
  configpanel = panel
end


function M.set_listpanel(panel)
  listpanel = panel
end


--- cache table that returns the display width of common strings.
-- This caches the string, but is more performant than looping over them everytime again
local common_string_width = setmetatable({}, {
  __index = function(t, k)
    local w = strwidth(k)
    t[k] = w
    return w
  end
})


--- Takes a list of lists, and padds each element to the max width of that column.
-- Returns a list of strings, each string being a row with '|' separated columns.
local function tableize(list)
  local col_widths = {}
  for _, row in ipairs(list) do
    for col_idx, value in ipairs(row) do
      local col_len = common_string_width[value]
      if not col_widths[col_idx] or col_len > col_widths[col_idx] then
        col_widths[col_idx] = col_len
      end
    end
  end

  local result = {}
  for _, row in ipairs(list) do
    local padded_cols = {}
    for col_idx, value in ipairs(row) do
      padded_cols[col_idx] = value .. string.rep(" ", col_widths[col_idx] - common_string_width[value])
    end
    result[#result + 1] = table.concat(padded_cols, " │ ")
  end

  return result
end


-- run a LuaRocks command asynchronously and return the result as a table of lines.
-- Arguments will be tostringed and quoted for the command line.
local function run_luarocks_command(...)
  local args = {...}
  local qargs = {}
  for i, arg in ipairs(args) do
    qargs[i] = '"' .. tostring(arg) .. '"'
  end
  local cmd = "luarocks " .. table.concat(qargs, " ")

  -- redirect stderr to stdout
  cmd = cmd .. " 2>&1"

  logpanel:add_line("> " .. cmd, true)

  local f, err = async.io_popen(cmd)
  if not f then
    logpanel:add_line("Lua error: " .. err, true)
    return nil, err
  end

  local result = {}
  while true do
    local line = f:read("*l")
    if not line then
      break
    end
    logpanel:add_line(line:gsub("\t", " "), true)
    result[#result + 1] = line
  end

  local s, et, ec = f:close()
  if not s then
    logpanel:add_line("# error: " .. tostring(et) .. " (" .. tostring(ec) .. ")", true)
    return nil, et, ec
  end

  return result
end


-- tests luarocks availability
function M.test_luarocks()
  return run_luarocks_command("--version")
end



--- Retrieves the config from LR.
-- Result is stored in lr_config and returned.
function M.refresh_config()
  local result = run_luarocks_command("config", "--json")
  if not result then
    return {
      error = "failed to collect LuaRocks config (check logs)"
    }
  end

  local config, err = json_decode(result[1])
  if not config then
    return {
      error = "failed to parse LuaRocks config: " .. tostring(err)
    }
  end

  lr_config = config

  local newline = string.char(0)
  local indent = "  "
  local array_continuation = " "
  local lines = split(json_encode(config, newline, indent, array_continuation), newline)

  configpanel:set_lines(lines)
  return config
end



--- returns the LR config from cache, or retrieves it if not cached yet.
function M.get_config()
  if lr_config == nil then
    M.refresh_config()
  end
  return lr_config
end


--- lists installed rocks
function M.list_rocks(tree)
  if tree then
    assert(type(tree) == "string", "tree must be a string")
    tree = "--tree=" .. tostring(tree)
  end
  local list = run_luarocks_command("list", "--porcelain", tree)
  if not list then
    return {}
  end
  for i, line in ipairs(list) do
    list[i] = split(line, "\t")
  end
  listpanel:set_lines(tableize(list))
end


return M

