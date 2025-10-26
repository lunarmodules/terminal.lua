#!/usr/bin/env lua

local terminal = require("terminal")
local copas = require("copas")

-- Run the main application inside the initialized terminal
local main = terminal.initwrap(require("luarocket.main"), {
  displaybackup = true,
  filehandle = io.stdout,
  sleep = copas.pause,  -- required for coroutine based multithreading
})

-- run the Copas scheduler
copas(function()
  main()
  copas.exit()  -- signal to other coroutines we're done
end)
