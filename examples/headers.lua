local t = require("terminal")
local ou = t.output
local s = t.text.stack
local p = t.cursor.position

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
	s.push(style)
	callback()
	s.pop()
end

-- Colors
local colors = {
  "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"
}
-- Inverse table of colors
local r_colors = {}
for index, color in ipairs(colors) do
	r_colors[color] = index
end

local rows, cols = t.size()

-- bar tui class
local function bar(o)
	return {
    rows = o.rows or 1,
    cols = o.cols or cols,
	  style = o.style or { fg = "white", bg = "black" },
		content_fn = o.content_fn,
		draw = function(self)
			with_style(self.style, function()
				p.set(self.rows, 1)
				ou.write(string.rep(" ", self.cols))
				if self.content_fn then
					self:content_fn()
				end
			end)
		end,
	}
end

-- text area tui class
local function textarea(o)
	return {
		rows = rows - 1,
		cursorY = 2,
		cursorX = 2,
    style =  (o or {}).style or { fg = "white", bg = "black" },
		index_fg = ((o or {}).style or {}).fg and r_colors[o.style.fg] or 8,
    index_bg = ((o or {}).style or {}).bg and r_colors[o.style.bg] or 1,
    -- draw the text area
		draw = function(self)
      s.pop()
			s.push(self.style)

			for i = 2, self.rows do
				p.set(i, 1)
				ou.write(string.rep(" ", cols))
			end

			self:update_cursor(2, 2)
		end,
    -- cycle colors
		cycle_color = function(self, isBackground)
			if isBackground then
				self.index_bg = (self.index_bg % #colors) + 1
				self.style.bg = colors[self.index_bg]
			else
				self.index_fg = (self.index_fg % #colors) + 1
				self.style.fg = colors[self.index_fg]
			end

			self:draw()
		end,
    -- update cursor, use internal cursor tracking
		update_cursor = function(self, y, x)
			self.cursorY = y
			self.cursorX = x
			p.set(y, x)
		end,
		color_info = function(self)
			return string.format("FG: %s, BG: %s", self.style.fg, self.style.bg)
		end,
	}
end

-- tui app class
local function TerminalUIApp(o)
	o = o or {}
	local app_name = o.app_name or "Terminal Application"
	local linesWritten = 0
  -- initiates the tui components
	local header
	local footer
	local content

  -- creates a content area
	content = textarea()

  -- creates the header
	header = bar({
		style = { fg = "white", bg = "green", brightness = "bright" },
    -- instruction for writing the header
		content_fn = function(self)
			local currentTime = os.date("%H:%M:%S")
			local cursorText = string.format("Pos: %d,%d", content.cursorY, content.cursorX)
			p.set(1, 2)
			ou.write(app_name)

			local clockPos = math.floor(self.cols / 4)
			p.set(1, clockPos)
			ou.write(currentTime)

			local cursorPos = math.floor(self.cols / 2) + 5
			p.set(1, cursorPos)
			ou.write(cursorText)

			local colorText = "Color: " .. content:color_info()
			p.set(1, self.cols - #colorText - 1)
			ou.write(colorText)
		end,
	})

  -- creates the footer
	footer = bar({
		rows = rows,
		style = { fg = "white", bg = "blue", brightness = "bright" },
    -- instruction for writing the footer
		content_fn = function(self)
			local lineText = "Lines: " .. linesWritten
			local helpText = "Ctrl+F: Change FG | Ctrl+B: Change BG | ESC: Exit"

			p.set(self.rows, 2)
			ou.write(lineText)

			p.set(self.rows, self.cols - #helpText - 1)
			ou.write(helpText)
		end,
	})

  -- redraw headers and restore original cursor position
	local function refresh_headers()
		local savedY, savedX = content.cursorY, content.cursorX

		header:draw()
		footer:draw()

		content:update_cursor(savedY, savedX)
	end

  -- handle key input
	local function handle_input()
		while true do

			local key_raw, key_name = read_key()

			if key_raw then
				if key_name == "escape" or key_name == "f10" then
					break
				elseif key_name == "ctrl-f" then
					content:cycle_color(false)
				elseif key_name == "ctrl-b" then
					content:cycle_color(true)
				elseif key_name == "enter" then
					linesWritten = linesWritten + 1

					if content.cursorY < rows - 1 then
						content:update_cursor(content.cursorY + 1, 2)
					else
						content:update_cursor(content.cursorY, 2)
						ou.write(string.rep(" ", cols))
					end
					refresh_headers()
				elseif key_name == "backspace" then
					if content.cursorX > 2 then
						content:update_cursor(content.cursorY, content.cursorX - 1)
						ou.write(" ")
						content:update_cursor(content.cursorY, content.cursorX)
					elseif content.cursorY > 2 then
						content:update_cursor(content.cursorY - 1, cols - 2)
					end
				elseif key_name == "up" and content.cursorY > 2 then
					content:update_cursor(content.cursorY - 1, content.cursorX)
				elseif key_name == "down" and content.cursorY < rows - 1 then
					content:update_cursor(content.cursorY + 1, content.cursorX)
				elseif key_name == "right" and content.cursorX < cols then
					content:update_cursor(content.cursorY, content.cursorX + 1)
				elseif key_name == "left" and content.cursorX > 2 then
					content:update_cursor(content.cursorY, content.cursorX - 1)
				elseif key_name == "home" then
					content:update_cursor(content.cursorY, 2)
				elseif key_name == "end" then
					content:update_cursor(content.cursorY, cols - 1)
				elseif #key_raw == 1 then
					ou.write(key_raw)
					content:update_cursor(content.cursorY, content.cursorX + 1)
				end
			end

			ou.flush()
		end
	end

	return function()
		t.initwrap({ displaybackup = true, filehandle = io.stdout }, function()
			t.clear.screen()
      refresh_headers()
			content:draw()
			handle_input()
		end)
		print("Thank you for using my_terminal! You wrote " .. linesWritten .. " lines.")
	end
end

-- create a new instance of the tui app
local tuiapp = TerminalUIApp()
-- run the app
tuiapp()
