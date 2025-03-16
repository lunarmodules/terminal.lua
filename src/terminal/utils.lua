--- Support functions.
-- @module terminal.utils



local M = {}



-- Converts table-keys to a string for error messages.
-- Takes a constants table, and returns a string containing the keys such that the
-- the string can be used in an error message.
-- Result is sorted alphabetically, with numbers first.
-- @tparam table constants The table containing the constants.
-- @treturn string A string containing the keys of the constants table.
local function constants_to_string(constants)
  local keys_str = {}
  local keys_num = {}
  for k, _ in pairs(constants) do
    if type(k) == "number" then
      table.insert(keys_num, k)
    else
      -- anything non-number; tostring + quotes
      table.insert(keys_str, '"' .. tostring(k) .. '"')
    end
  end

  table.sort(keys_num)
  table.sort(keys_str)

  for _, k in ipairs(keys_str) do
    table.insert(keys_num, k)
  end

  return table.concat(keys_num, ", ")
end



--- Returns an error message for an invalid lookup constant.
-- This function is used to generate error messages for invalid arguments.
-- @tparam number|string value The value that wasn't found.
-- @tparam table constants The valid values for the constant.
-- @tparam[opt="Invalid value: "] prefix the prefix for the message.
-- @treturn string The error message.
function M.invalid_constant(value, constants, prefix)
  local prefix = prefix or "Invalid value: "
  local list = constants_to_string(constants)
  if type(value) == "number" then
    value = tostring(value)
  else
    value = '"' .. tostring(value) .. '"'
  end

  return prefix .. value .. ". Expected one of: " .. list
end



--- Throws an error message for an invalid lookup constant.
-- This function is used to generate error messages for invalid arguments.
-- @tparam number|string value The value that wasn't found.
-- @tparam table constants The valid values for the constant.
-- @tparam[opt="Invalid value: "] prefix the prefix for the message.
-- @tparam[opt=1] err_lvl the error level when throwing the error.
-- @return nothing, throws an error.
function M.throw_invalid_constant(value, constants, prefix, err_lvl)
  err_lvl = (err_lvl or 1) + 1 -- +1 to add this function itself
  error(M.invalid_constant(value, constants, prefix), err_lvl)
  -- unreachable
end



--- Converts a lookup table to a constant table with error reporting.
-- The constant table modified in-place, a metatable with an __index metamethod
-- is added to the table. This metamethod throws an error when an invalid key is
-- accessed.
-- @tparam[opt="value"] string value_type The type of value looked up, use a singular,
-- eg. "cursor shape", or "foreground color".
-- @tparam table t The lookup table.
-- @treturn table The same constant table t, with a metatable added.
function M.make_lookup(value_type, t)
  local value_type = value_type or "value"

  setmetatable(t, {
    __index = function(self, key)
      M.throw_invalid_constant(key, self, "Invalid " .. value_type .. ": ", 2)
    end,
  })

  return t
end



return M
