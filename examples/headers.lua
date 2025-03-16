local sys = require("system")
local t = require("terminal")

-- Keys
local key_names = {
  ["\27[A"] = "up",
  ["\27[B"] = "down",
  ["\27[C"] = "right",
  ["\27[D"] = "left",
  ["\127"] = "backspace",
  ["\8"] = "backspace",
  ["\27[3~"] = "delete",
  ["\27[H"] = "home",
  ["\27[F"] = "end",
  ["\27"] = "escape",
  ["\9"] = "tab",
  ["\27[Z"] = "shift-tab",
  ["\r"] = "enter",
  ["\n"] = "enter",
  ["f10"] = "f10",
  ["\6"] = "ctrl-f",
  ["\2"] = "ctrl-b",
}

-- Colors
local colors = {
  "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"
}

-- Terminal UI class
local TerminalUI = {}

-- Constructor
function TerminalUI:new(options)
  options = options or {}
  local instance = {
    appName = options.appName or "Terminal Application",
    linesWritten = 0,
    cursorY = 2,
    cursorX = 2,
    headerStyle = options.headerStyle or {fg = "white", bg = "blue", brightness = "bright"},
    footerStyle = options.footerStyle or {fg = "white", bg = "blue", brightness = "bright"},
    contentStyle = options.contentStyle or {fg = "green", bg = "black", brightness = "normal"},
    currentFgColorIndex = 3,
    currentBgColorIndex = 1,
  }
  setmetatable(instance, {__index = self})
  return instance
end
-- cycle color
function TerminalUI:cycleColor(isBackground)
  if isBackground then
    self.currentBgColorIndex = (self.currentBgColorIndex % #colors) + 1
    self.contentStyle.bg = colors[self.currentBgColorIndex]
  else
    self.currentFgColorIndex = (self.currentFgColorIndex % #colors) + 1
    self.contentStyle.fg = colors[self.currentFgColorIndex]
  end

  t.textset(self.contentStyle)
  self:refreshDisplay()
end

function TerminalUI:getCurrentColorInfo()
  return string.format("FG: %s, BG: %s",
    colors[self.currentFgColorIndex],
    colors[self.currentBgColorIndex])
end

function TerminalUI:readKey()
  local key = t.input.readansi(1)
  return key, key_names[key] or key
end

function TerminalUI:withStyle(style, callback)
  t.textpush(style)
  callback()
  t.textpop()
end

function TerminalUI:drawBar(row, style, contentFn)
  local _, cols = sys.termsize()

  self:withStyle(style, function()
    t.cursor_set(row, 1)
    t.output.write(string.rep(" ", cols))

    if contentFn then
      contentFn(row, cols)
    end
  end)
end

function TerminalUI:updateCursor(y, x)
  self.cursorY = y
  self.cursorX = x
  t.cursor_set(y, x)
end

function TerminalUI:drawHeader()
  local currentTime = os.date("%H:%M:%S")
  local cursorText = string.format("Pos: %d,%d", self.cursorY, self.cursorX)

  self:drawBar(1, self.headerStyle, function(_, cols)
    t.cursor_set(1, 2)
    t.output.write(self.appName)

    local clockPos = math.floor(cols / 4)
    t.cursor_set(1, clockPos)
    t.output.write(currentTime)

    local cursorPos = math.floor(cols / 2) + 5
    t.cursor_set(1, cursorPos)
    t.output.write(cursorText)

    local colorText = "Color: " .. self:getCurrentColorInfo()
    t.cursor_set(1, cols - #colorText - 1)
    t.output.write(colorText)
  end)
end

function TerminalUI:drawFooter()
  local rows, _ = sys.termsize()
  local lineText = "Lines: " .. self.linesWritten
  local helpText = "Ctrl+F: Change FG | Ctrl+B: Change BG | ESC: Exit"

  self:drawBar(rows, self.footerStyle, function(_, cols)

    t.cursor_set(rows, 2)
    t.output.write(lineText)

    t.cursor_set(rows, cols - #helpText - 1)
    t.output.write(helpText)
  end)
end

function TerminalUI:refreshDisplay()
  local savedY, savedX = self.cursorY, self.cursorX

  self:drawHeader()
  self:drawFooter()

  self:updateCursor(savedY, savedX)
end

function TerminalUI:initializeContent()
  local rows, cols = sys.termsize()

  t.textset(self.contentStyle)

  for i = 2, rows - 1 do
    t.cursor_set(i, 1)
    t.output.write(string.rep(" ", cols))
  end

  self:updateCursor(2, 2)
end

function TerminalUI:handleInput()
  local rows, cols = sys.termsize()

  self:refreshDisplay()

  while true do
    t.cursor_set(self.cursorY, self.cursorX)

    local rawKey, keyName = self:readKey()

    if rawKey then
      if keyName == "escape" or keyName == "f10" then
        break
      elseif keyName == "ctrl-f" then
        self:cycleColor(false)
      elseif keyName == "ctrl-b" then
        self:cycleColor(true)
      elseif keyName == "enter" then
        self.linesWritten = self.linesWritten + 1

        if self.cursorY < rows - 1 then
          self:updateCursor(self.cursorY + 1, 2)
        else
          self:updateCursor(self.cursorY, 2)
          t.output.write(string.rep(" ", cols))
        end
        self:refreshDisplay()
      elseif keyName == "backspace" then
        if self.cursorX > 2 then
          self:updateCursor(self.cursorY, self.cursorX - 1)
          t.output.write(" ")
          self:updateCursor(self.cursorY, self.cursorX)
        elseif self.cursorY > 2 then
          self:updateCursor(self.cursorY - 1, cols - 2)
        end
      elseif keyName == "up" and self.cursorY > 2 then
        self:updateCursor(self.cursorY - 1, self.cursorX)
      elseif keyName == "down" and self.cursorY < rows - 1 then
        self:updateCursor(self.cursorY + 1, self.cursorX)
      elseif keyName == "right" and self.cursorX < cols then
        self:updateCursor(self.cursorY, self.cursorX + 1)
      elseif keyName == "left" and self.cursorX > 2 then
        self:updateCursor(self.cursorY, self.cursorX - 1)
      elseif keyName == "home" then
        self:updateCursor(self.cursorY, 2)
      elseif keyName == "end" then
        self:updateCursor(self.cursorY, cols - 1)
      elseif #rawKey == 1 then
        t.output.write(rawKey)
        self:updateCursor(self.cursorY, self.cursorX + 1)
      end
    end

    t.output.flush()
  end
end

function TerminalUI:run()
  t.initialize{
    displaybackup = true,
    filehandle = io.stdout,
  }
  t.clear.screen()

  self:initializeContent()
  self:handleInput()

  t.shutdown()
  print("Thank you for using MyTerminal! You wrote " .. self.linesWritten .. " lines.")
end

local myTerminal = TerminalUI:new({
  appName = "The best terminal ever",
  headerStyle = {fg = "white", bg = "blue", brightness = "bright"},
  footerStyle = {fg = "white", bg = "blue", brightness = "bright"},
  contentStyle = {fg = "green", bg = "black", brightness = "normal"}
})

myTerminal:run()
