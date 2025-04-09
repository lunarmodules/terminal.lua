-- src/terminal/util/class.lua
return function(base)
  local c = {}
  if base then
    setmetatable(c, { __index = base })
    c.__base = base
  end

  c.__index = c

  function c:new(...)
    local instance = setmetatable({}, self)
    if instance.init then
      instance:init(...)
    end
    return instance
  end

  return c
end
