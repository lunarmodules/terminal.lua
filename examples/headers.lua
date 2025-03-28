local sys = require("system")
local t = require("terminal")
local to = t.output
local tts = t.text.stack
local tcp = t.cursor.position

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
-- Utility function to read a key from terminal input
local function read_key()
  local key = t.input.readansi(1) -- Read a single key
  return key, key_names[key] or key -- Return raw key and mapped name
end

-- Utility function to draw components using the stack style
local function with_style(style, callback)
  tts.push(style)
  callback()
  tts.pop()
end

-- Colors
local colors = {
  "black",
  "red",
  "green",
  "yellow",
  "blue",
  "magenta",
  "cyan",
  "white",
}
local rcolors = {}
for index, color in ipairs(colors) do
  rcolors[color] = index
end

-- TUI classes
local TerminalUIApp = {}
local Bar = {}
local TextArea = {}

-- Constructor: TerminalUIApp: Full-screen TUI App
function TerminalUIApp:new(options)
  options = options or {}
  local instance = {
    app_name = options.app_name or "Terminal Application",
    header = options.header or Bar:new(),
    footer = options.footer or Bar:new(),
    content = options.content or TextArea:new(),
    linesWritten = 0,
  }
  setmetatable(instance, { __index = self })
  -- circular reference between components and parent tui app
  instance.content.parent_app = instance.content.parent_app or instance
  instance.header.parent_app = instance.header.parent_app or instance
  instance.footer.parent_app = instance.footer.parent_app or instance
  return instance
end

function TerminalUIApp:run()
  t.initialize({
    displaybackup = true,
    filehandle = io.stdout,
  })
  t.clear.screen()

  self.content:draw()
  self.content:handle_input()

  t.shutdown()
  print("Thank you for using my_terminal! You wrote " .. self.linesWritten .. " lines.")
end

function TerminalUIApp:refresh_display()
  local savedY, savedX = self.content.cursorY, self.content.cursorX
  local rows, _ = sys.termsize()

  self.header:draw(1)
  self.footer:draw(rows)

  self.content:update_cursor(savedY, savedX)
end

-- Constructor: TextArea: main content area
function TextArea:new(options)
  options = options or {}
  local instance = {
    parent_app = options.parent_app,
    cursorY = 2,
    cursorX = 2,
    style = options.style or { fg = "green", bg = "black", brightness = "normal" },
  }
  instance.index_fg = instance.style.fg and rcolors[instance.style.fg] or 3
  instance.index_bg = instance.style.bg and rcolors[instance.style.bg] or 1
  setmetatable(instance, { __index = self })
  return instance
end

-- cycle colors
function TextArea:cycle_color(isBackground)
  if isBackground then
    self.index_bg = (self.index_bg % #colors) + 1
    self.style.bg = colors[self.index_bg]
  else
    self.index_fg = (self.index_fg % #colors) + 1
    self.style.fg = colors[self.index_fg]
  end

  self:draw()
  self.parent_app:refresh_display()
end

function TextArea:color_info()
  return string.format("FG: %s, BG: %s", colors[self.index_fg], colors[self.index_bg])
end

function TextArea:update_cursor(y, x)
  self.cursorY = y
  self.cursorX = x
  tcp.set(y, x)
end

function TextArea:draw()
  local rows, cols = sys.termsize()

  tts.pop()
  tts.push(self.style)

  for i = 2, rows - 1 do
    tcp.set(i, 1)
    to.write(string.rep(" ", cols))
  end

  self:update_cursor(2, 2)
end

function TextArea:handle_input()
  local rows, cols = sys.termsize()

  self.parent_app:refresh_display()

  while true do
    tcp.set(self.cursorY, self.cursorX)

    local key_raw, key_name = read_key()

    if key_raw then
      if key_name == "escape" or key_name == "f10" then
        break
      elseif key_name == "ctrl-f" then
        self:cycle_color(false)
      elseif key_name == "ctrl-b" then
        self:cycle_color(true)
      elseif key_name == "enter" then
        self.parent_app.linesWritten = self.parent_app.linesWritten + 1

        if self.cursorY < rows - 1 then
          self:update_cursor(self.cursorY + 1, 2)
        else
          self:update_cursor(self.cursorY, 2)
          to.write(string.rep(" ", cols))
        end
        self.parent_app:refresh_display()
      elseif key_name == "backspace" then
        if self.cursorX > 2 then
          self:update_cursor(self.cursorY, self.cursorX - 1)
          to.write(" ")
          self:update_cursor(self.cursorY, self.cursorX)
        elseif self.cursorY > 2 then
          self:update_cursor(self.cursorY - 1, cols - 2)
        end
      elseif key_name == "up" and self.cursorY > 2 then
        self:update_cursor(self.cursorY - 1, self.cursorX)
      elseif key_name == "down" and self.cursorY < rows - 1 then
        self:update_cursor(self.cursorY + 1, self.cursorX)
      elseif key_name == "right" and self.cursorX < cols then
        self:update_cursor(self.cursorY, self.cursorX + 1)
      elseif key_name == "left" and self.cursorX > 2 then
        self:update_cursor(self.cursorY, self.cursorX - 1)
      elseif key_name == "home" then
        self:update_cursor(self.cursorY, 2)
      elseif key_name == "end" then
        self:update_cursor(self.cursorY, cols - 1)
      elseif #key_raw == 1 then
        to.write(key_raw)
        self:update_cursor(self.cursorY, self.cursorX + 1)
      end
    end

    to.flush()
  end
end

-- Constructor: Bar: horizontal bar in the screen
function Bar:new(options)
  options = options or {}
  local instance = {
    style = options.style or { fg = "white", bg = "blue", brightness = "bright" },
    content_fn = options.content_fn,
  }
  setmetatable(instance, { __index = self })
  return instance
end

function Bar:draw(row)
  local _, cols = sys.termsize()

  with_style(self.style, function()
    tcp.set(row, 1)
    to.write(string.rep(" ", cols))

    if self.content_fn then
      self:content_fn(row, cols)
    end
  end)
end

-- Initiate two bars of Bar for header and footer
local my_header = Bar:new({
  style = { fg = "white", bg = "blue", brightness = "bright" },
  content_fn = function(self, _, cols)
    local currentTime = os.date("%H:%M:%S")
    local cursorText = string.format("Pos: %d,%d", self.parent_app.content.cursorY, self.parent_app.content.cursorX)
    tcp.set(1, 2)
    to.write(self.parent_app.app_name)

    local clockPos = math.floor(cols / 4)
    tcp.set(1, clockPos)
    to.write(currentTime)

    local cursorPos = math.floor(cols / 2) + 5
    tcp.set(1, cursorPos)
    to.write(cursorText)

    local colorText = "Color: " .. self.parent_app.content:color_info()
    tcp.set(1, cols - #colorText - 1)
    to.write(colorText)
  end,
})
local my_footer = Bar:new({
  style = { fg = "white", bg = "blue", brightness = "bright" },
  content_fn = function(self, _, cols)
    local rows, _ = sys.termsize()
    local lineText = "Lines: " .. self.parent_app.linesWritten
    local helpText = "Ctrl+F: Change FG | Ctrl+B: Change BG | ESC: Exit"

    tcp.set(rows, 2)
    to.write(lineText)

    tcp.set(rows, cols - #helpText - 1)
    to.write(helpText)
  end,
})

local my_terminal = TerminalUIApp:new({
  app_name = "The best terminal ever",
  header = my_header,
  footer = my_footer,
})

my_terminal:run()
