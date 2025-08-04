--- Support functions.
-- @module terminal.utils



local M = {}

local utf8 = require("utf8") -- explicit, since 5.1 en 5.2 don't have it by default


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
-- @tparam[opt="Invalid value: "] string prefix the prefix for the message.
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
-- @tparam[opt="Invalid value: "] string prefix the prefix for the message.
-- @tparam[opt=1] number err_lvl the error level when throwing the error.
-- @return nothing, throws an error.
function M.throw_invalid_constant(value, constants, prefix, err_lvl)
  err_lvl = (err_lvl or 1) + 1 -- +1 to add this function itself
  error(M.invalid_constant(value, constants, prefix), err_lvl)
  -- unreachable
end



--- Converts a lookup table to a constant table with user friendly error reporting.
-- The constant table is modified in-place, a metatable with an __index metamethod
-- is added to the table. This metamethod throws an error when an invalid key is
-- accessed.
-- @tparam[opt="value"] string value_type The type of value looked up, use a singular,
-- eg. "cursor shape", or "foreground color".
-- @tparam table t The lookup table.
-- @treturn table The same constant table t, with a metatable added.
-- @usage
-- local cursor_shape = M.make_lookup("cursor shape", {
--   block = 0,
--   underline = 1,
--   bar = 2,
-- })
--
-- local value = cursor_shape["bad-shape"] -- throws an error;
-- -- Invalid cursor shape: "bad-shape". Expected one of: "block", "underline", "bar"
function M.make_lookup(value_type, t)
  local value_type = value_type or "value"

  setmetatable(t, {
    __index = function(self, key)
      M.throw_invalid_constant(key, self, "Invalid " .. value_type .. ": ", 2)
    end,
  })

  return t
end



--- Resolve indices.
-- This function resolves negative indices to positive indices.
-- The result will be capped into the range [`min_value`, `max_value`].
-- @tparam number index The index to resolve.
-- @tparam number max_value The maximum value for the index.
-- @tparam[opt=1] number min_value The minimum value for the index.
function M.resolve_index(index, max_value, min_value)
  if index < 0 then
    index = max_value + index + 1
  end

  min_value = min_value or 1
  if index < min_value then
    index = min_value
  end

  if index > max_value then
    index = max_value
  end

  return index
end



do
  -- copy class methods and properties into an instance table.
  -- traverses up the chain to copy all methods and properties of ancestors as well.
  local function copy_class_methods(cls)
    local instance = {}
    while cls do
      for k, v in pairs(cls) do
        if not rawget(instance, k) then
          instance[k] = v
        end
      end

      cls = cls.super
    end

    return instance
  end



  -- init placholder for proper usage
  local function init_instance()
    error("the 'init' method should never be called directly", 2)
  end



  -- upon instantiation, create a 'fat' instance, copying all class + ancestor methods
  -- into the instance, so that they can be called without the class lookup chain.
  local function constructor(cls, ...)
    assert(rawget(cls, "__index"), "Constructor can only be called on a Class")

    -- populate the instance
    local instance = copy_class_methods(cls)

    -- clear unused entries, used only for classes
    instance.__call = nil
    instance.__index = nil

    instance.super = cls
    setmetatable(instance, cls)

    if instance.init then
      instance.init = nil
      cls.init(instance, ...)
    end
    instance.init = init_instance

    return instance
  end



  local base = {}
  base.__index = base
  base.__call = constructor


  --- Creates a (sub)class.
  -- This function creates a new class, which is a subclass of the given baseclass.
  -- An instance can be created by calling on the class, any parameteres passed in will be passed on
  -- to the `init` method. The `init` method (if present), will be called upon instantiation.
  --
  -- Every instance will:
  --
  -- - have a `super` property, which points to the class itself.
  -- - upon creation call the `init` method (if present) with the parameters passed when calling on the Class.
  -- @tparam[opt] class baseclass The base-class to inherit from.
  -- @treturn table The new class.
  -- @usage
  -- local Cat = utils.class()
  -- function Cat:init(value)
  --   self.value = value or 42
  -- end
  --
  -- local Lion = utils.class(Cat)
  -- function Lion:init(value)
  --   assert(self.super == Cat, "Superclass is not a Cat")
  --   Cat.init(self, value)   -- call ancestor initializer
  --   self.value = self.value * 2
  -- end
  --
  -- local instance1 = Lion()
  -- print(instance1.value)      --> 84
  -- local instance2 = Lion(10)
  -- print(instance2.value)      --> 20
  function M.class(baseclass)
    baseclass = baseclass or base
    assert(rawget(baseclass, "__index"), "Baseclass is not a Class, can only subclass a Class")
    local class = setmetatable({}, baseclass)
    class.__index = class
    class.__call = constructor
    class.super = baseclass

    return setmetatable(class, baseclass)
  end
end



--- Like `string:sub`, returns the substring of the string from `i` to `j` inclusive, but operates on utf8 characters.
-- @tparam string str the string to take the substring of
-- @tparam number i the starting index of the substring
-- @tparam number j the ending index of the substring
-- @treturn string the substring
function M.utf8sub(str, i, j)
  local n = utf8.len(str)
  if #str == n then -- fast path, no utf8 codes
    return str:sub(i, j)
  end

  i = i or 1
  j = j or -1
  i = ((i - (i >= 0 and 1 or 0)) % n) + 1
  j = ((j - (j >= 0 and 1 or 0)) % n) + 1
  if j < i then
    return ""
  end
  local indices = {}
  for pos, _ in utf8.codes(str) do
    indices[#indices + 1] = pos
  end
  indices[#indices + 1] = #str + 1
  return str:sub(indices[i], indices[j + 1] - 1)
end



return M
