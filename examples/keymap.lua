-- Example to test and show keyboard input

local t = require("terminal")
local keymap = t.input.keymap.default_key_map
local keys = t.input.keymap.default_keys
local print = t.output.print
local write = t.output.write


local function yellow(str)
  return t.text.stack.push_seq({fg="yellow"}) .. str .. t.text.stack.pop_seq()
end



local function to_hex_debug_format(str)
  local hex_part = ""
  local char_part = ""

  for i = 1, #str do
    local byte = string.byte(str, i)
    local char = str:sub(i, i)

    hex_part = hex_part .. string.format("%02X", byte) .. " "
    if byte < 32 or byte > 126 then
      char_part = char_part .. "."
    else
      char_part = char_part .. char
    end
  end

  return yellow("\ttext: ") .. char_part .. yellow("\n\thex : ") .. hex_part
end



local function main()
  repeat
    write("Press 'q' to exit, any other key to see its name and aliasses...")
    local key, keytype = t.input.readansi(math.huge)
    t.cursor.position.column(1)
    t.clear.eol()

    if not key then
      print(yellow("an error occured while reading input: "))
      print(to_hex_debug_format(key))

    elseif key == "q" then
      print(yellow("Exiting!"))

    else
      print(yellow("received a '") .. keytype .. yellow("' key:"))
      print(to_hex_debug_format(key))

      local keyname = keymap[key]
      print(yellow("\tit has the internal name: '") .. tostring(keyname) .. yellow("'"))
      print(yellow("\tit maps to the names:"))
      for k, v in pairs(keys) do
        if v == keyname then
          print("\t\t" .. k)
        end
      end
      print()

    end
  until key == "q"
end



t.initwrap(main, {
  displaybackup = false,
  filehandle = io.stdout,
  disable_sigint = true,
})()
