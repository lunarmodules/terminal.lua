-- Example demonstrating the progress.Bar class.
--
-- Displays five progress bars simultaneously:
--   1. A classic fill bar (0–100 %) with block tip chars, running 20 seconds.
--   2. A reverse "car race" bar — car emoji tip, dots for road, blank for cleared road.
--   3. A styled download bar with label, color attrs, and a percentage format string.
--   4. A loop-mode bar — resets and fills again every 4 seconds.
--   5. A bounce-mode bar — oscillates back and forth every 10 seconds.

local t   = require "terminal"
local Bar = require "terminal.progress.bar"


local DURATION = 20  -- seconds for one full pass of bars 1-3


local function make_bars()
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
    status      = "complete   ", -- padded so width stays stable as status changes
    label_attr  = { fg = "magenta", brightness = "high" },
    filled_attr = { fg = "magenta", brightness = "high" },
    empty_attr  = { fg = "white",   brightness = "low" },
    cap_attr    = { fg = "magenta", brightness = "normal" },
    status_attr = { fg = "magenta", brightness = "normal" },
  }

  -- Bar 4: loop mode — fills to max, then wraps back and starts again.
  -- Cycles every 4 seconds; cycle number shown in status.
  local bar4 = Bar {
    min         = 0,
    max         = 100,
    mode        = Bar.modes.loop,
    left_cap    = "[",
    right_cap   = "] ",
    tip_chars   = Bar.block_tip_chars.block,
    filled_char = "█",
    empty_char  = " ",
    label       = "Loop     ",
    status      = "cycle 1",
    label_attr  = { fg = "blue",  brightness = "high" },
    filled_attr = { fg = "blue",  brightness = "high" },
    empty_attr  = { fg = "white", brightness = "low" },
    cap_attr    = { fg = "blue",  brightness = "normal" },
    status_attr = { fg = "blue",  brightness = "normal" },
  }

  -- Bar 5: bounce mode — fills left-to-right then reverses right-to-left.
  -- Completes one full bounce every 10 seconds; direction arrow shown in status.
  local bar5 = Bar {
    min         = 0,
    max         = 100,
    mode        = Bar.modes.bounce,
    left_cap    = "[",
    right_cap   = "] ",
    tip_chars   = {"<=>"},
    filled_char = " ",
    empty_char  = " ",
    label       = "Bounce   ",
    status      = "→",
    label_attr  = { fg = "red",   brightness = "high" },
    filled_attr = { fg = "red",   brightness = "high" },
    empty_attr  = { fg = "white", brightness = "low" },
    cap_attr    = { fg = "red",   brightness = "normal" },
    status_attr = { fg = "red",   brightness = "normal" },
  }

  return bar1, bar2, bar3, bar4, bar5
end


local function render_bars(bars, row_start)
  local _, cols = t.size()
  for i, bar in ipairs(bars) do
    t.cursor.position.set(row_start + i - 1, 1)
    t.output.write(tostring(bar:render(cols)))
  end
end


local function main()
  local rows, _ = t.size()
  local bar1, bar2, bar3, bar4, bar5 = make_bars()
  local bars = { bar1, bar2, bar3, bar4, bar5 }

  -- Center bars vertically: 1 header row + #bars bar rows
  local row_start = math.floor((rows - #bars - 1) / 2) + 2

  t.cursor.visible.set(false)
  t.clear.screen()

  local sys   = require "system"
  local start = sys.gettime()

  while true do
    local elapsed = sys.gettime() - start

    -- Bars 1-3: clamp mode, complete over DURATION seconds
    local raw = elapsed / DURATION * 100
    bar1:set(raw)
    bar2:set(raw)
    bar3:set(raw)
    if elapsed >= DURATION then
      bar3:set_status("complete   ")
    elseif elapsed >= DURATION / 2 then
      bar3:set_status("unpacking  ")
    else
      bar3:set_status("downloading")
    end

    -- Bar 4: loop mode, 4-second cycle
    local cycle_secs = 4
    bar4:set(elapsed / cycle_secs * 100)
    bar4:set_status("cycle " .. tostring(math.floor(elapsed / cycle_secs) + 1))

    -- Bar 5: bounce mode, 5-second half-cycle (10 s full bounce)
    local half_secs = 5
    bar5:set(elapsed / half_secs * 100)
    local going_forward = (elapsed / half_secs * 100) % 200 <= 100
    bar5:set_status(going_forward and "→" or "←")

    render_bars(bars, row_start)
    t.output.flush()

    if elapsed >= DURATION then
      break
    end

    if t.input.readansi(0.05) then
      break
    end
  end

  -- Pause so the finished state is visible; any key exits
  t.input.readansi(10)
  t.cursor.position.set(rows, 1)
  t.cursor.visible.set(true)
end


t.initwrap(main, { displaybackup = true })()
