local t = require "terminal"
local Sequence = require("terminal.sequence")

-- Key bindings for arrow keys, 'j', 'k', and Enter.
local key_names = {
  ["\27[A"] = "up",  -- Up arrow key
  ["k"] = "up",      -- 'k' key
  ["\27[B"] = "down",-- Down arrow key
  ["j"] = "down",    -- 'j' key
  ["\r"] = "enter",  -- Carriage return (Enter)
  ["\n"] = "enter",  -- Newline (Enter)
}
local greenDiamond = "◇"
local pipe         = "│"
local hook         = "└"
local circle       = "○"
local dot          = "●"
local IMenu = {}
local M = {}

-- Initialize choices, cursor position, and selected option.
M.choices = {} -- Array of selectable options (strings).
M.selected = 1 -- The option the user selects

local function _template()
    local menu = greenDiamond .. "  Select an option:\n"
    for _, option in pairs(M.choices) do
        menu = menu .. pipe .. "    " .. circle .. " " .. option .. "\n"
    end
    t.text.stack.push{ -- Dim the text color.
        fg = "white",
        brightness = "dim",
    }
    print(menu)
    t.text.stack.pop()
end

function IMenu:choices(chs)
    -- choices may only be strings
    for _, val in pairs(chs) do
        if type(val) ~= "string" then
            return nil, "expected choices to be string but got" .. type(val) .. " instead"
        end
    end

    M.choices = chs
    return true, nil
end


-- Displays an unselected option.
-- @param string : the option name you want to unselect
local function _unselect(opt)
    t.output.write(Sequence(function() return t.text.stack.push_seq{ -- Dim the text color.
        fg = "white",
        brightness = "dim",
    }end,
    pipe, "    ", circle, " ", opt, "\n",
    t.text.stack.pop_seq, -- Restore text color.
    t.cursor.position.up_seq(1)))

end

-- Displays a selected option.
-- @param string : the option name you want to select
local function _select(opt)
    t.output.write(Sequence(
    pipe, "    ", dot, " ", opt, "\n",
    t.cursor.position.up_seq(1)
    ))
end



local function _readKey()
    local key = t.input.readansi(1)
    return key, key_names[key] or key
end

local function _handleInput()
    if #M.choices == 0 then
        return nil, "choices empty"
    end

    local max = #M.choices
    local min = 1
    local idx = 1                                    -- Index of the currently highlighted option.
    t.cursor.position.up(max+1)                         -- Offset cursor for initial display.
    _select(M.choices[1])                   -- Highlight the first option.
    while true do
        local  _, keyName = _readKey()

        if keyName == "up" and idx > min then
            _unselect(M.choices[idx])
            t.cursor.position.up(1)
            idx = idx - 1
            M.selected = idx
            _select(M.choices[idx])
        elseif keyName == "down" and idx < max then
            _unselect(M.choices[idx])
            t.cursor.position.down(1)
            idx = idx + 1
            M.selected = idx
            _select(M.choices[idx])
        elseif keyName == "enter" then
            M.selected = idx                            -- Set the selected option index.
            t.cursor.position.down(max - idx+1)             -- Move cursor past the options.
            return M.selected                            -- Return the selected index.
        end
    end
end

local function _exit()
  t.output.write(Sequence(
  t.cursor.position.down_seq(#M.choices - M.selected),
  pipe.."\n",
  t.cursor.position.down_seq(1),
  hook,
  function() return t.text.stack.push_seq{ -- Dim the text color.
        fg = "red",
        brightness = "bright",
    }end,
    " operation cancelled", "\n",
    t.text.stack.pop_seq
    ))

end


-- Runs the prompt and returns the selected option index.
function IMenu:run()
    t.initialize()
    t.cursor.visible.set(false)                     -- Hide the cursor.
    _template()
    local ok, selected = pcall(_handleInput)
    t.output.write("\n")
    t.cursor.visible.set(true)                       -- Restore cursor visibility.
    t.shutdown()

    if not ok then
      _exit()
      return nil
    end

    return selected
end


local c = {"Typescript", "Typescript + swc", "Javascript", "Javascript + swc"}
IMenu:choices(c)

local selected_index = IMenu:run()

if selected_index then
  print("selected: " .. c[selected_index])
else
  print("Error or cancellation.")
end

return IMenu
