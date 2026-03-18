-- This example demonstrates the use of the text-attribute stack, and how to
-- use it to manage text attributes in a more structured way.

local t = require("terminal")
local p = require("terminal.progress")
local color = require("terminal.text.color")

local function main()
  -- create one of each spinners
  local spinners = {}
  local sprite_names = {}

  -- enumerate all sprites and create room to display them
  for name in pairs(p.sprites) do
    print("     " .. name)
    sprite_names[#sprite_names + 1] = name
  end
  print("     colored_dot")
  print("     path_progress")
  print("                                                       <-- ticker type")

  -- create all spinners with fixed positions (positions are optional)
  local r = t.cursor.position.get()
  local num_sprites = #sprite_names
  local base_row = r - num_sprites - 4

  for i, name in ipairs(sprite_names) do
    local done_sprite, done_textattr
    if i <= num_sprites / 2 then
      done_sprite = "✔  "
      done_textattr = { fg = "green", brightness = 3 }
    end
    spinners[#spinners + 1] = p.spinner({
      sprites = p.sprites[name],
      col = 1,
      row = base_row + i,
      done_textattr = done_textattr,
      done_sprite = done_sprite,
    })
  end

  spinners[#spinners + 1] = p.spinner({
    sprites = {
      color.fore_seq("red") .. "●",
      color.fore_seq("green") .. "●",
      color.fore_seq("yellow") .. "●",
      color.fore_seq("cyan") .. "●",
    },
    col = 1,
    row = r - 3,
  })

  local path_row = r - 2
  local progress_val = 0

  -- add the ticker as the last spinner
  spinners[#spinners + 1] = p.spinner({
    sprites = p.ticker("🕓-Please wait-🎹...", 30, "Done!"),
    col = 1,
    row = r - 1,
    textattr = { fg = "black", bg = "red", brightness = "normal" },
    done_textattr = { brightness = "high" },
  })
  t.cursor.position.set(r, 1)
  t.output.write("Press any key to stop the spinners...")
  t.cursor.visible.set(false)
  t.cursor.position.set(path_row, 1)
  local progress_sequence = t.cursor.position.backup_seq() .. t.cursor.position.set_seq(path_row, 1)

  -- loop until key-pressed
  while true do
    for _, spinner in ipairs(spinners) do
      spinner()
    end
    progress_val = (progress_val + 1) % 101
    t.output.write(progress_sequence)
    t.output.write(p.progress_path(progress_val, 30, "🏠", "🚙"))
    t.output.write(t.cursor.position.restore_seq())
    t.output.flush()
    if t.input.readansi(0.05) then
      break
    end
  end

  -- mark spinners done
  for _, spinner in ipairs(spinners) do
    spinner(true)
  end
  t.cursor.position.set(path_row, 1)
  t.output.write("\27[K")
  t.cursor.position.set(r, 1)
  t.cursor.visible.set(true)
  t.output.write("\n") -- move one line below the ticker, into clean space
end

-- run the main function, wrapped in terminal init/shutdown
t.initwrap(main)()
