local terminal = require("terminal")
local position = require("terminal.cursor.position")
local Sequence = require("terminal.sequence")
local utils    = require("terminal.utils")

local keys = terminal.input.keymap.get_keys()
local keymap = terminal.input.keymap.get_keymap {
  ["j"] = keys.down,
  ["k"] = keys.up,
  ["h"] = keys.left,
  ["l"] = keys.right,
  ["ctrl_c"] = keys.escape
}

local background =
[[
🙶🙸-====-🙠 ^🙧 🙴.🙥 %🙡 -=====-🙸🙷
|                           |
|   ---------------------   🙖
🙑  | 🙾               🌙  |  |
|  |        /            |  |
|  |  _🌷_  __/  ___ _   |  🙑
|  _-___________________-_  |
| /---/--/-/-+-\-\--\--\--\ |
|/__/_/_/----+-----\__\____\|
➹------/🙠 ^🙧 🙴.🙥 %🙡 \--------
]]
local character = "🐄" --
local xc, yc = 14, 5

terminal.initwrap(function()
  terminal.output.write("use arrows to move the cow, esc to exit\n")
  terminal.output.write(background)
  local top, bottom do
    local r, c = position.get()
    bottom = position.set_seq(r, c)
    top = position.set_seq(r - 10, 1)
  end

  terminal.cursor.visible.set(false)

  local renderer = Sequence(
    top,
    background,
    top,
    function()
      return position.move_seq(yc, xc)
    end,
    character,
    bottom
  )

  while true do
    terminal.output.write(renderer)
    local keyname = keymap[terminal.input.readansi(0.02)]
    if keyname == keys.up then
      yc = utils.resolve_index(yc - 1, 5, 4)

    elseif keyname == keys.down then
      yc = utils.resolve_index(yc + 1, 5, 4)

    elseif keyname == keys.left then
      xc = utils.resolve_index(xc - 1, 23, 5)

    elseif keyname == keys.right then
      xc = utils.resolve_index(xc + 1, 23, 5)

    elseif keyname == keys.escape then
      terminal.cursor.visible.set(true)
      print('Moo!')
      break
    end
  end
end)()
