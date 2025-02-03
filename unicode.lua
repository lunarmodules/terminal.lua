local t = require("terminal")
local w = require("terminal.width")
local p = require("terminal.progress")
local sys = require("system")

local pr

local function test()
  local stime = sys.gettime()
  for n = 0, #pr do
    local sprite = pr[n]
    local c = w.write_swidth(sprite)
    t.write(c,"\n")
  end

  t.write(("-time: %.1f s"):format(sys.gettime() - stime).."\n")
end


assert(t.initwrap(function()
  pr = p.sprites.bar_horizontal
  pr[0] = "✔"
  test()
  test()
  pr = p.sprites.moon
  pr[math.random( 0,8)] = "✔"
  local stime = sys.gettime()
  w.preload(table.concat(pr))
  t.write(("-time: %.1f s"):format(sys.gettime() - stime).."\n")
  test()
  test()
  return true
end))
