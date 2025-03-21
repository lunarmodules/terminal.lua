-- This example demonstrates the use of the text-attribute stack, and how to
-- use it to manage text attributes in a more structured way.

local t = require("terminal")



local function main()
  -- clear the screen, and move cursor to top-left
  t.clear.screen()
  t.cursor.position.stack.push(1,1)

  -- push text attribues on the stack
  t.textpush{
    fg = "white",
    brightness = "dim",
  }
  t.output.print("Hello dim white World!")


  t.textpush{
    fg = "white",
    bg = "blue",
    brightness = "normal",
  }
  t.output.print("Hello white on blue World!")


  t.textpush{
    fg = "red",
    bg = "black",
    brightness = "bright",
  }
  t.output.print("Hello bright red World!")

  -- Unwind the stack, and restore text attributes along the way
  t.textpop()
  t.output.print("Hello white on blue World! (again)")

  t.textpop()
  t.output.print("Hello dim white World! (again)")

  t.textpop()
  t.output.write("Press any key, or wait 5 seconds...")
  t.output.flush()
  t.input.readansi(5)

  return true
end



-- initialize terminal; backup (switch to alternate buffer) and set output to stdout
local opts = {
  displaybackup = true,
  filehandle = io.stdout,
}
assert(t.initwrap(opts, main))

print("done!")  -- this is printed on the original screen buffer
