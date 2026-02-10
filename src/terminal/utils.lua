--- Support functions.
-- @module terminal.utils



local M = {}
package.loaded["terminal.utils"] = M -- Register the module early to avoid circular dependencies

local utf8 = require("utf8") -- explicit, since 5.1 en 5.2 don't have it by default
local width  -- forward declaration, 'required' later to prevent loops


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
-- @within Constants
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
-- @within Constants
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
-- @within Constants
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
-- @within Generic
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
  -- @within Classes
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
-- @usage
-- -- UTF-8 double-width characters (Chinese, etc.)
-- utf8sub("你好", 1, 2)       -- "你好"
-- utf8sub("你好", 1, 1)       -- "你"
-- utf8sub("你好世界", 2, 3)    -- "好世"
-- @within Text
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



--- Like `string:sub`, returns the substring of the string from `i` to `j` inclusive, but operates on display columns.
-- It uses `text.width.utf8cwidth` to determine the width of each character.
-- @tparam string str the string to take the substring of
-- @tparam number i the starting column of the substring (can't be negative!)
-- @tparam number j the ending column of the substring (can't be negative!)
-- @tparam[opt=false] boolean no_pad whether to pad the substring with spaces
-- if the first or last column contains half of a double-width character
-- @treturn string the substring
-- @usage
-- -- UTF-8 double-width characters (2 columns each)
-- utf8sub_pos("你好世界", 3, 6)  -- "好世" (columns 3-6)
-- utf8sub_pos("你好世界", 2, 7)  -- " 好世 " (columns 2-7 with padding for half of double-width chars)
-- utf8sub_pos("你好世界", 2, 7, true)  -- "好世" (columns 2-7, no_pad == true)
-- @within Text
function M.utf8sub_col(str, i, j, no_pad)
  i = i or 1
  j = j or math.huge
  assert(i >= 1, "Starting column must be positive")
  assert(j >= 1, "Ending column must be positive")
  if j < i then
    return ""
  end

  local first_byte = nil  -- position where column i starts
  local prefix = ""       -- prefix string; either "" or " " in case of padding
  local last_byte = nil   -- position where column j ends
  local postfix = ""      -- postfix string; either "" or " " in case of padding
  local current_width = 0

  if i == 1 then
    first_byte = 1
  end
  if j == math.huge then
    last_byte = #str
  end

  -- print("str:", str)
  -- print("byte-length:", #str)

  for byte_pos, codepoint in utf8.codes(str) do
    -- print("byte_pos:", byte_pos, "char:", utf8.char(codepoint))
    local char_width = width.utf8cwidth(codepoint)
    -- print("char_width:", char_width)
    local new_width = current_width + char_width
    -- print("current_width:", current_width)

    if not first_byte then
      if current_width + 1 == i then  -- exact match
        first_byte = byte_pos

      elseif new_width == i then   -- start pos is 2nd col of double-width char
        prefix = no_pad and "" or " "
        first_byte = byte_pos + #utf8.char(codepoint)   -- first byte of next utf8 char
      end

      -- print("first_byte:", first_byte)
    end

    if first_byte then
      if new_width == j then      -- exact match
        last_byte = byte_pos + #utf8.char(codepoint) - 1
        break

      elseif new_width > j then   -- end pos is 1st col of double-width char
        postfix = no_pad and "" or " "
        last_byte = byte_pos - 1   -- last byte of previous utf8 char
        break
      end
    end

    current_width = new_width
  end

  if not first_byte then
    return ""         -- start column is beyond the string
  end

  if not last_byte then
    last_byte = #str  -- Ending column is beyond the string
  end

  -- print("prefix:", prefix, "first_byte:", first_byte, "last_byte:", last_byte, "postfix:", postfix)
  return prefix .. str:sub(first_byte, last_byte) .. postfix
end



--- Strips all ANSI escape sequences from a string.
-- Removes CSI (e.g. colors, cursor movement, SGR), OSC, DCS, SOS, PM, APC,
-- two-byte sequences, and C1 control codes. Use when you need plain text
-- without terminal control sequences.
-- @tparam string str The string that may contain ANSI sequences.
-- @treturn string The string with all ANSI sequences removed.
-- @usage
-- strip_ansi("\27[31mred\27[0m")  -- "red"
-- @within Text
function M.strip_ansi(str)
  return str               -- Note: order is important here
    :gsub("\27%].-\7", "")                -- OSC (terminated by BEL)
    :gsub("\27%].-\27%\\", "")            -- OSC (terminated by ST)
    :gsub("\27[P^X_].-\27%\\", "")        -- DCS, SOS, PM, APC
    :gsub("\27%[[0-?]*[ -/]*[@-~]", "")   -- CSI
    :gsub("\155[0-?]*[ -/]*[@-~]", "")    -- C1 CSI
    :gsub("\27[@-_]", "")                 -- two-byte sequences
end



--- Truncates text to fit within a given width, adding ellipsis as needed.
-- Shortens text if necessary, adds ellipsis when truncated. Respects UTF-8
-- character boundaries and handles double-width characters correctly.
-- @tparam number width The available width for the text in columns.
-- @tparam[opt=""] string text The text to truncate.
-- @tparam[opt="right"] string trunc_type The type of truncation to apply:
--   - "right": Truncate from the right, show beginning of text with ellipsis on the right
--   - "left": Truncate from the left, show end of text with ellipsis on the left
--   - "drop": Drop the entire text if it doesn't fit (return empty string).
-- @tparam[opt="…"] string ellipsis The ellipsis string to use. Defaults to Unicode ellipsis character "…".
--   Can be a multi-character string or empty string.
-- @treturn string The truncated text (may be empty string).
-- @treturn number The size of the returned text in columns.
-- @usage
-- -- Truncate from right (default)
-- truncate_ellipsis(10, "Very long text")  -- "Very long…"
-- -- Truncate from left
-- truncate_ellipsis(10, "Very long text", "left")  -- "…long text"
-- -- Drop if too small
-- truncate_ellipsis(3, "Very long text", "drop")  -- ""
-- -- Custom ellipsis
-- truncate_ellipsis(10, "Very long text", "right", "..")  -- "Very lon.."
-- -- Empty string as ellipsis just truncates the text
-- truncate_ellipsis(10, "Very long text", "left", "")  -- " long text"
-- @within Text
function M.truncate_ellipsis(width, text, trunc_type, ellipsis)
  if text == nil or text == "" then
    return "", 0
  end
  trunc_type = trunc_type or "right"
  ellipsis = ellipsis or "…"  -- Unicode ellipsis character (U+2026)
  local EditLine = require "terminal.editline"
  local width_module = require("terminal.text.width")

  local text_w = width_module.utf8swidth(text)
  local ellipsis_w = width_module.utf8swidth(ellipsis)

  if width >= text_w then
    -- enough space for text
    return text, text_w

  elseif width <= ellipsis_w or trunc_type == "drop" then
    -- too little space for text (or ellipsis doesn't fit), omit it altogether
    return "", 0

  elseif trunc_type == "right" then -- truncate the text from the right
    width = width - ellipsis_w  -- reserve space for ellipsis
    local el_text = EditLine(text):goto_index(width+1)
    while el_text:pos_col() - 1 > width do
      el_text:left()
    end
    el_text = el_text:sub_char(1, el_text:pos_char() - 1)
    return tostring(el_text) .. ellipsis, el_text:len_col() + ellipsis_w

  else -- truncate the text from the left
    width = width - ellipsis_w  -- reserve space for ellipsis
    local el_text = EditLine(text):left(width + 1)
    local l = el_text:len_col()
    while l - el_text:pos_col() >= width do
      el_text:right()
    end
    el_text = el_text:sub_char(el_text:pos_char(), -1)
    return ellipsis .. tostring(el_text), el_text:len_col() + ellipsis_w
  end
end



width = require("terminal.text.width") -- load only now, to prevent loops
return M
