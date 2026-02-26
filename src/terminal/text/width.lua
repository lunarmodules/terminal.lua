-- Character display width helpers (LuaSystem 0.7.0+).
--
-- Delegates to system.utf8cwidth / utf8swidth.
-- Ambiguous-width characters (East-Asian) default to 1 but can be calibrated
-- once at startup to match what the actual terminal does.
--
-- @module terminal.text.width

local M = {}


local sys = require "system"
local t = require "terminal"
-- Stored ambiguous width (1 or 2). 
-- Default = 1 (safe for most modern terminals and non-TTY output).
local AMBIGUOUS_WIDTH = 1 -- Default

--Getter and setter for ambiguous width, in case users want to manage it themselves or check it after calibration.
function M.get_ambiguous_width()
    return AMBIGUOUS_WIDTH
end
-- Manually sets the ambiguous width setting.
-- @tparam number width must be 1 or 2
function M.set_ambiguous_width(width)
    if width ~= 1 and width ~= 2 then
        error("ambiguous_width must be 1 or 2, got " .. tostring(width))
    end
    AMBIGUOUS_WIDTH = width
end



-- Calibrates the ambiguous width by probing one character.
-- Only runs when we have a real TTY. Idempotent.
-- @return number the detected width (1 or 2)
function M.calibrate()
    if not t.output.isatty() then return AMBIGUOUS_WIDTH end
    
    if not t.ready() then
        error("terminal must be initialized before calibration")
    end

    local r, c = t.cursor.position.get()
    if not r then return AMBIGUOUS_WIDTH end

    -- Write an ambiguous character ("middle dot") and measure displacement
    t.output.write("·") 
    t.output.flush()
    
    local _, new_c = t.cursor.position.get()
    t.cursor.position.set(r, c) -- Restore cursor

    if new_c then
        local measured = new_c - c
        if measured == 1 or measured == 2 then
            AMBIGUOUS_WIDTH = measured
        end
    end
    return AMBIGUOUS_WIDTH
end

function M.utf8cwidth(char)
  return sys.utf8cwidth(char, AMBIGUOUS_WIDTH)
end
function M.utf8swidth(str)
  return sys.utf8swidth(str, AMBIGUOUS_WIDTH)
end

return M