-- File: headers.lua
local sys = require("system")
local t = require("terminal")

-- Shared key mappings
local key_names = {
  ["\27[A"] = "up", ["\27[B"] = "down", ["\27[C"] = "right", ["\27[D"] = "left",
  ["\127"] = "backspace", ["\8"] = "backspace", ["\27[3~"] = "delete",
  ["\27[H"] = "home", ["\27[F"] = "end", ["\27"] = "escape", ["\9"] = "tab",
  ["\27[Z"] = "shift-tab", ["\r"] = "enter", ["\n"] = "enter", ["f10"] = "f10",
  ["\6"] = "ctrl-f", ["\2"] = "ctrl-b",
}

-- Shared colors
local colors = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}

-- Component: StyleManager
local StyleManager = {}
function StyleManager:new(initialStyle)
  local instance = {style = initialStyle or {fg = "green", bg = "black", brightness = "normal"}}
  setmetatable(instance, {__index = self})
  return instance
end
function StyleManager:apply(callback)
  t.textpush(self.style)
  callback()
  t.textpop()
end
function StyleManager:set()
  t.textset(self.style)
end

-- Component: BarRenderer
local BarRenderer = {}
function BarRenderer:new(styleManager)
  local instance = {styleManager = styleManager}
  setmetatable(instance, {__index = self})
  return instance
end
function BarRenderer:render(row, contentFn)
  local _, cols = sys.termsize()
  self.styleManager:apply(function()
    t.cursor_set(row, 1)
    t.output.write(string.rep(" ", cols))
    if contentFn then contentFn(row, cols) end
  end)
end

-- Component: ColorCycler
local ColorCycler = {}
function ColorCycler:new(styleManager, initialFgIndex, initialBgIndex)
  local instance = {
    styleManager = styleManager,
    fgIndex = initialFgIndex or 3,
    bgIndex = initialBgIndex or 1
  }
  setmetatable(instance, {__index = self})
  return instance
end
function ColorCycler:cycle(isBackground)
  if isBackground then
    self.bgIndex = (self.bgIndex % #colors) + 1
    self.styleManager.style.bg = colors[self.bgIndex]
  else
    self.fgIndex = (self.fgIndex % #colors) + 1
    self.styleManager.style.fg = colors[self.fgIndex]
  end
  self.styleManager:set()
end
function ColorCycler:getInfo()
  return string.format("FG: %s, BG: %s", colors[self.fgIndex], colors[self.bgIndex])
end

-- Component: CursorController
local CursorController = {}
function CursorController:new(initialY, initialX)
  local instance = {y = initialY or 2, x = initialX or 2}
  setmetatable(instance, {__index = self})
  return instance
end
function CursorController:set(y, x)
  self.y, self.x = y, x
  t.cursor_set(y, x)
end
function CursorController:get()
  return self.y, self.x
end

-- Component: HeaderBar
local HeaderBar = {}
function HeaderBar:new(appName, renderer, cycler, cursor)
  local instance = {
    appName = appName or "Terminal Application",
    renderer = renderer,
    cycler = cycler,
    cursor = cursor
  }
  setmetatable(instance, {__index = self})
  return instance
end
function HeaderBar:draw()
  local time = os.date("%H:%M:%S")
  local y, x = self.cursor:get()
  self.renderer:render(1, function(_, cols)
    t.cursor_set(1, 2)
    t.output.write(self.appName)
    t.cursor_set(1, math.floor(cols / 4))
    t.output.write(time)
    t.cursor_set(1, math.floor(cols / 2) + 5)
    t.output.write(string.format("Pos: %d,%d", y, x))
    local colorText = "Color: " .. self.cycler:getInfo()
    t.cursor_set(1, cols - #colorText - 1)
    t.output.write(colorText)
  end)
end

-- Component: FooterBar
local FooterBar = {}
function FooterBar:new(renderer)
  local instance = {renderer = renderer, lines = 0}
  setmetatable(instance, {__index = self})
  return instance
end
function FooterBar:draw()
  local rows, _ = sys.termsize()
  self.renderer:render(rows, function(_, cols)
    t.cursor_set(rows, 2)
    t.output.write("Lines: " .. self.lines)
    local help = "Ctrl+F: Change FG | Ctrl+B: Change BG | ESC: Exit"
    t.cursor_set(rows, cols - #help - 1)
    t.output.write(help)
  end)
end
function FooterBar:incrementLines()
  self.lines = self.lines + 1
end

-- Component: ContentManager
local ContentManager = {}
function ContentManager:new(styleManager, cursor)
  local instance = {styleManager = styleManager, cursor = cursor}
  setmetatable(instance, {__index = self})
  return instance
end
function ContentManager:init()
  local rows, cols = sys.termsize()
  self.styleManager:set()
  for i = 2, rows - 1 do
    t.cursor_set(i, 1)
    t.output.write(string.rep(" ", cols))
  end
  self.cursor:set(2, 2)
end

-- Main Terminal Application
local TerminalApp = {}
function TerminalApp:new(options)
  options = options or {}
  local contentStyle = StyleManager:new(options.contentStyle)
  local headerStyle = StyleManager:new(options.headerStyle)
  local footerStyle = StyleManager:new(options.footerStyle)
  local cursor = CursorController:new(2, 2)
  local cycler = ColorCycler:new(contentStyle, 3, 1)
  
  local instance = {
    header = HeaderBar:new(options.appName, BarRenderer:new(headerStyle), cycler, cursor),
    footer = FooterBar:new(BarRenderer:new(footerStyle)),
    content = ContentManager:new(contentStyle, cursor),
    cycler = cycler,
    cursor = cursor
  }
  setmetatable(instance, {__index = self})
  return instance
end
function TerminalApp:refresh()
  self.header:draw()
  self.footer:draw()
  local y, x = self.cursor:get()
  self.cursor:set(y, x)
end
function TerminalApp:run()
  t.initialize{displaybackup = true, filehandle = io.stdout}
  t.clear.screen()
  
  self.content:init()
  self:refresh()
  
  local rows, cols = sys.termsize()
  while true do
    local rawKey = t.input.readansi(1)
    local keyName = rawKey and (key_names[rawKey] or rawKey)
    
    if keyName then
      if keyName == "escape" or keyName == "f10" then break
      elseif keyName == "ctrl-f" then self.cycler:cycle(false); self:refresh()
      elseif keyName == "ctrl-b" then self.cycler:cycle(true); self:refresh()
      elseif keyName == "enter" then
        self.footer:incrementLines()
        local y, x = self.cursor:get()
        if y < rows - 1 then
          self.cursor:set(y + 1, 2)
        else
          self.cursor:set(y, 2)
          t.output.write(string.rep(" ", cols))
        end
        self:refresh()
      elseif keyName == "backspace" then
        local y, x = self.cursor:get()
        if x > 2 then
          self.cursor:set(y, x - 1)
          t.output.write(" ")
          self.cursor:set(y, x - 1)
        elseif y > 2 then
          self.cursor:set(y - 1, cols - 2)
        end
      elseif keyName == "up" then
        local y, x = self.cursor:get()
        if y > 2 then self.cursor:set(y - 1, x) end
      elseif keyName == "down" then
        local y, x = self.cursor:get()
        if y < rows - 1 then self.cursor:set(y + 1, x) end
      elseif keyName == "right" then
        local y, x = self.cursor:get()
        if x < cols then self.cursor:set(y, x + 1) end
      elseif keyName == "left" then
        local y, x = self.cursor:get()
        if x > 2 then self.cursor:set(y, x - 1) end
      elseif keyName == "home" then
        local y = self.cursor:get()
        self.cursor:set(y, 2)
      elseif keyName == "end" then
        local y = self.cursor:get()
        self.cursor:set(y, cols - 1)
      elseif #rawKey == 1 then
        t.output.write(rawKey)
        local y, x = self.cursor:get()
        self.cursor:set(y, x + 1)
      end
    end
    t.output.flush()
  end
  
  t.shutdown()
  print("Thank you for using MyTerminal! You wrote " .. self.footer.lines .. " lines.")
end

-- Usage
local app = TerminalApp:new({
  appName = "The best terminal ever",
  headerStyle = {fg = "white", bg = "blue", brightness = "bright"},
  footerStyle = {fg = "white", bg = "blue", brightness = "bright"},
  contentStyle = {fg = "green", bg = "black", brightness = "normal"}
})
app:run()