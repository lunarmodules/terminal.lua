local t = require("terminal")
local progress= require("terminal.progress")

local ProgressSpinner = progress.ProgressSpinner
local sprites = progress.sprites

local function main()
  local r, _ = t.cursor.position.get()
  local spinner = ProgressSpinner:new{
    sprites = sprites.spinner,
    col = 1,
    row = r - 2,
    stepsize = 0.1,
    textattr = {fg = "blue", brightness = "normal"},
    done_sprite = "✔ ",
    done_textattr = {fg = "green", brightness = "bright"},
  }

  t.output.write("Press any key to stop the spinner...\n")
  t.cursor.visible.set(false)

  -- Spinner loop
  while true do
    spinner:step_once()
    t.output.flush()
    if t.input.readansi(0.02) then break end
  end

  -- Mark done
  spinner:step_once(true)
  t.cursor.visible.set(true)
  t.output.write("\n")
end

t.initwrap(main)()
