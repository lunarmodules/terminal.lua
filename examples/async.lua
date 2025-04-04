-- An example of asynchoneous input and output using the `copas` library.
-- This example shows how to use the `copas` library to create a simple
-- terminal application that displays the current time and waits for keyboard input.

local copas = require("copas")
local t = require("terminal")



-- add timer display thread
copas.addthread(function()

  local function updatetime(time)
    local dt = os.date(" %H:%M:%S ", time)
    t.output.write(
      t.cursor.position.stack.push_seq(1, - #dt),
      t.text.stack.push_seq{ fg = "black", bg = "white" },
      dt,
      t.text.stack.pop_seq(),
      t.cursor.position.stack.pop_seq()
    )
  end

  while not copas.exiting() do
    local t = copas.gettime()
    updatetime(math.floor(t))
    copas.pause(1 - (t - math.floor(t))) -- sleep until the next second
  end
end)



-- add thread waiting for keyboard input
copas.addthread(function()
  t.output.print("Press 'q' to exit...")

  while not copas.exiting() do
    local key = t.input.readansi(math.huge)
    if key then
      t.output.print("You pressed: " .. key:gsub("\027", "\\027"))
      if key == "q" then
        copas.exit()
      end
    end
  end
end)



-- start the copas loop, wrapped in term setup/teardown
t.initwrap({
  displaybackup = true,
  filehandle = io.stdout,
  sleep = copas.pause, -- ensure readansi is yielding
}, copas.loop)
