-- Minimal developer-oriented terminal monitor.
-- Demonstrates terminal rendering loop, system metrics integration,
-- and a simple UI abstraction using terminal.lua.

local terminal = require("terminal")

local function read_command(command)
  local handle = io.popen(command)
  if not handle then
    return nil
  end

  local output = handle:read("*a")
  handle:close()
  if output == "" then
    return nil
  end

  return output
end

local function read_cpu_sample()
  local stat = read_command("cat /proc/stat")
  if not stat then
    return nil
  end

  local line = stat:match("([^\n]+)")
  if not line or not line:match("^cpu%s+") then
    return nil
  end

  local values = {}
  for value in line:gmatch("%d+") do
    values[#values + 1] = tonumber(value)
  end

  local idle = (values[4] or 0) + (values[5] or 0)
  local total = 0
  for i = 1, 8 do
    total = total + (values[i] or 0)
  end

  return {
    idle = idle,
    total = total,
  }
end

local function cpu_percent(previous)
  local sample = read_cpu_sample()
  if not sample then
    return nil, previous
  end

  if not previous then
    return nil, sample
  end

  local total_delta = sample.total - previous.total
  local idle_delta = sample.idle - previous.idle
  if total_delta <= 0 then
    return nil, sample
  end

  local percent = 100 * (1 - idle_delta / total_delta)
  return math.max(0, math.min(100, percent)), sample
end

local function read_memory()
  local output = read_command("free -m")
  if not output then
    return nil
  end

  local total, used, available = output:match("Mem:%s+(%d+)%s+(%d+)%s+%d+%s+%d+%s+%d+%s+(%d+)")
  if not total then
    total, used = output:match("Mem:%s+(%d+)%s+(%d+)")
  end

  total = tonumber(total)
  used = tonumber(used)
  available = tonumber(available)
  if not total or not used or total <= 0 then
    return nil
  end

  if available then
    used = total - available
  end

  return {
    percent = math.max(0, math.min(100, used / total * 100)),
  }
end

local function progress_bar(percent, width)
  width = math.max(4, width or 24)
  if not percent then
    return "[" .. string.rep("-", width) .. "]"
  end

  local filled = math.floor(width * percent / 100 + 0.5)
  return "[" .. string.rep("#", filled) .. string.rep("-", width - filled) .. "]"
end

local function clear_screen()
  io.write("\27[2J\27[H")
end

local function draw(cpu, memory)
  clear_screen()
  print("System Monitor (sys_monitor.lua)")
  print("")

  if cpu then
    print(string.format("CPU    %s %5.1f%%", progress_bar(cpu, 24), cpu))
  else
    print("CPU    " .. progress_bar(nil, 24) .. "  --.-%")
  end

  if memory then
    print(string.format("Memory %s %5.1f%%", progress_bar(memory.percent, 24), memory.percent))
  else
    print("Memory " .. progress_bar(nil, 24) .. "  --.-%")
  end

  print("")
  print("Current time: " .. os.date("%H:%M:%S"))
  print("")
  print("Press q to quit")
end

terminal.initwrap(function()
  local cpu_state
  local cpu_value
  local memory

  terminal.cursor.visible.set(false)

  while true do
    cpu_value, cpu_state = cpu_percent(cpu_state)
    memory = read_memory()
    draw(cpu_value, memory)
    terminal.output.flush()

    local input = terminal.input.readansi(1)
    if input == "q" or input == "\3" then
      break
    end
  end
  terminal.cursor.visible.set(true)
end, { displaybackup = true, disable_sigint = true, filehandle = io.stdout })()
