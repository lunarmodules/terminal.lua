-- Example demonstrating the progress.Bar class.
--
-- Displays three progress bars simultaneously:
--   1. A classic fill bar (0–100 %) with block tip chars, running 20 seconds.
--   2. A reverse "car race" bar — car emoji tip, dots for road, blank for cleared road.
--   3. A styled download bar with label, color attrs, and a percentage format string.

local t   = require "terminal"
local Bar = require "terminal.progress.bar"


local DURATION = 20  -- seconds for one full pass


local function make_bars(cols)
  -- Bar 1: classic block fill, 0–100 %
  local bar1 = Bar {
    min         = 0,
    max         = 100,
    left_cap    = "[",
    right_cap   = "] ",
    tip_chars   = Bar.block_tip_chars.block,
    filled_char = "█",
    empty_char  = " ",
    label       = "Loading  ",
    format      = "%3.0f%%",
    label_attr  = { fg = "cyan", brightness = "normal" },
    filled_attr = { fg = "green", brightness = "high" },
    empty_attr  = { fg = "white", brightness = "low" },
    cap_attr    = { fg = "white", brightness = "normal" },
    status_attr = { fg = "cyan", brightness = "normal" },
  }

  -- Bar 2: reverse — car drives right to left as progress grows.
  -- The car emoji is the tip, dots are the "road ahead", blanks are "road cleared".
  local bar2 = Bar {
    min         = 0,
    max         = 100,
    left_cap    = "🏁",
    right_cap   = " ",
    tip_chars   = { "🚗" },
    filled_char = " ",
    empty_char  = "·",
    reverse     = true,
    label       = "Car race ",
    format      = "%3.0fm",
    label_attr  = { fg = "yellow", brightness = "high" },
    filled_attr = { fg = "white",  brightness = "low" },
    empty_attr  = { fg = "white",  brightness = "normal" },
    cap_attr    = { fg = "yellow", brightness = "normal" },
    status_attr = { fg = "yellow", brightness = "normal" },
  }

  -- Bar 3: download style with colored sections and a status string
  local bar3 = Bar {
    min         = 0,
    max         = 100,
    left_cap    = "▕",
    right_cap   = "▏",
    filled_char = "▓",
    empty_char  = "░",
    label       = "Labels   ",
    format      = "%3.0f%% ",
    status      = "complete   ", -- padded to make sure it doesn't shift the bar as it changes
    label_attr  = { fg = "magenta", brightness = "high" },
    filled_attr = { fg = "magenta", brightness = "high" },
    empty_attr  = { fg = "white",   brightness = "low" },
    cap_attr    = { fg = "magenta", brightness = "normal" },
    status_attr = { fg = "magenta", brightness = "normal" },
  }

  return bar1, bar2, bar3
end


local function render_bars(bars, row_start)
  local _, cols = t.size()

  for i, bar in ipairs(bars) do
    t.cursor.position.set(row_start + i - 1, 1)
    t.output.write((bar:render(cols)))
  end
end


local function main()
  local rows, cols = t.size()

  -- Reserve 5 lines: 1 header + 3 bars + 1 footer
  local row_start = math.floor((rows - 5) / 2) + 2
  local bar1, bar2, bar3 = make_bars(cols)
  local bars = { bar1, bar2, bar3 }

  t.cursor.visible.set(false)
  t.clear.screen()

  -- Header
  t.cursor.position.set(row_start - 1, 1)
  t.output.write(
    string.rep(" ", math.floor((cols - 35) / 2)) .. "  progress.Bar  example full-bars  ")
  t.text.pop()

  local start = require("system").gettime()

  while true do
    local now     = require("system").gettime()
    local elapsed = now - start
    local pct     = math.min(100, elapsed / DURATION * 100)

    bar1:set(pct)
    bar2:set(pct)
    bar3:set(pct)
    -- bar3 status: switch label
    if pct >= 100 then
      bar3:set_status("complete   ")
    elseif pct >= 50 then
      bar3:set_status("unpacking  ")
    else
      bar3:set_status("downloading")
    end

    render_bars(bars, row_start)

    if pct >= 100 then
      break
    end

    if t.input.readansi(0.1) then
      break
    end
  end

  -- Pause briefly so the full bar is visible, exit on any key
  t.input.readansi(10)
  t.cursor.position.set(rows, 1)
  t.cursor.visible.set(true)
end


t.initwrap(main, { displaybackup = true })()
