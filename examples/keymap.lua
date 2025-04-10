-- Example to test and show keyboard input

local t = require("terminal")
local keymap = t.input.keymap.default_key_map
local keys = t.input.keymap.default_keys
local print = t.output.print
local write = t.output.write


local function main()
  repeat
    write("Press 'q' to exit, any other key to see its name and aliasses...")
    local key, keytype = t.input.readansi(math.huge)
    t.cursor.position.column(1)
    t.clear.eol()

    if not key then
      print("an error occured while reading input: " .. tostring(key))

    elseif key == "q" then
      print("Exiting!")

    else
      if #key == 1 and key:sub(1,1):byte() < 32 then
        print("received a '" .. keytype .."' control character: " .. tostring(key:sub(1,1):byte()))
      else
        print("received a '" .. keytype .."' key: '" .. key:gsub("\027", "\\027").."' (" .. tostring(#key) .. " bytes)")
      end
      local keyname = keymap[key]
      print("\tit has the internal name: '" .. tostring(keyname) .. "'")
      print("\tit maps to the names:")
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
})()
