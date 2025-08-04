--- Sequence class.
-- A sequence object is an array of items, where each item can be a string or a function.
-- When the sequence is converted to a string, the functions are executed and their return
-- value is used.
-- This allows for dynamic use of the "stack" based functions.
--
-- - call on the class to instatiate it, passing the items as arguments
-- - concatenating two sequences with the "+" operator returns a new one of the 2 combined
-- - converting the sequence to a string will execute any functions and concatenate the results
-- - sequences can be nested inside other sequences
-- - sequence length is tracked in field `n`, if not present `#sequence` is used (an empty sequence has no `n` field)
--
-- Example:
--     local Seq = require "terminal.sequence"
--
--     local seq1 = Seq("hello", " ", "world")
--     local seq2 = Seq("foo", function() return "---" end, "bar") -- functions as members
--     local seq3 = seq1 + seq2                                    -- concatenation of sequences
--     local seq4 = Seq(seq1, " ", seq2)                           -- nested sequences
--
--     print(seq1)  -- "hello world"
--     print(seq2)  -- "foo---bar"
--     print(seq3)  -- "hello worldfoo---bar"
--     print(seq4)  -- "hello world foo---bar"
--
-- @classmod Sequence



local pack = function(...) return {n = select("#", ...), ...} end



local S = {}
S.__index = S

setmetatable(S, {
  -- call on the class to instantiate it
  __call = function(self, ...)
    local result = setmetatable(pack(...), S)
    if result.n == 0 then
      result.n = nil
    end
    return result
  end
})


-- concat all entries, whilst executing the functions
S.__tostring = function(self)
  local result = {}
  for i = 1, (self.n or #self) do
    local item = self[i]
    if type(item) == "function" then
      item = item()
    end
    result[i] = tostring(item)
  end
  return table.concat(result)
end



-- concat 2 sequences, by copying both into a new sequence
S.__add = function(self, other)
  local result = {}
  local size = self.n or #self
  for i = 1, size do
    result[i] = self[i]
  end
  if getmetatable(other) == S then
    -- another sequence, copy all items
    local size2 = other.n or #other
    for i = 1, size2 do
      result[size + i] = other[i]
    end
    result.n = size + size2
  else
    result[#result + 1] = other
    result.n = size + 1
  end
  return setmetatable(result, S)
end



return S
