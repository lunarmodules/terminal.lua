-- This example demonstrates the use of the text-attribute stack, and how to
-- use it to manage text attributes in a more structured way.

local t = require("terminal")
local p = require("terminal.progress")


local function main()
  -- create one of each spinners
  local spinners = {}

  -- create room to display the spinners
  local lst = {}
  for name, seq in pairs(p.sprites) do
    print("     "..name) -- create a line for display
    lst[#lst+1] = name
  end
  print("                                                       <-- ticker type")

  -- create all spinners with fixed positions (positions are optional)
  local r, _ = t.cursor.position.get()
  for i, name in ipairs(lst) do
    local done_sprite, done_textattr
    if i <= #lst/2 then
      -- set done to checkmark character for the first half of the spinners
      done_sprite = "✔  "
      done_textattr = {fg = "green", brightness = 3}
    end
    spinners[#spinners+1] = p.spinner {
      sprites = p.sprites[name],
      col = 1,
      row = r - #lst - 2 + i,
      done_textattr = done_textattr,
      done_sprite = done_sprite,
    }
  end


  -- add the ticker one last
  spinners[#spinners+1] = p.spinner {
    -- uses utf8 character
    sprites = p.ticker("🕓-Please wait-🎹...", 30, "Done!"),
    col = 1,
    row = r - 1,
    textattr = {fg = "black", bg = "red", brightness = "normal"},
    done_textattr = {brightness = "high"},
  }


  t.output.write("Press any key to stop the spinners...")
  t.cursor.visible.set(false)


  -- loop until key-pressed
  while true do
    for _, s in ipairs(spinners) do
      s()
    end
    t.output.flush()
    if t.input.readansi(0.02) then
      break -- a key was pressed
    end
  end

  -- mark spinners done
  for _, s in ipairs(spinners) do
    s(true)
  end
  t.cursor.visible.set(true)
  t.output.print() -- move to new line (we're still on the 'press any key' line)
end

-- run the main function, wrapped in terminal init/shutdown
t.initwrap({}, main)
