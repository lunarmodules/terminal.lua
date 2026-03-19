--- Simple car racing game demonstrating a terminal game loop.
--
-- This example shows how to build a game loop using the terminal library.
-- It demonstrates cursor positioning, 256-color text attributes, non-blocking
-- key input with a timeout, and the alternate display buffer for clean
-- full-screen output.
--
-- Use the [a] and [d] keys to steer left and right, and avoid the rocks (🪨).
-- The game speeds up over time. Press [n] at the start screen to quit.

local terminal = require "terminal"
local write = terminal.output.write
local read_key = terminal.input.readansi
local set_pos = terminal.cursor.position.set_seq
local fg = terminal.text.color.fore_seq
local bg = terminal.text.color.back_seq
local RESET_SEQ = "\27[0m"



local config = {
  lane_count = 3,
  lane_spacing = 4,
  lane_offset = 2,
  road_height = 12,
  player_row = 12,
  spawn_rate = 0.25,
  speed_initial = 0.12,
  speed_min = 0.04,
  speed_decay = 0.005,
  speed_interval = 40,
  divider_period = 4,
  divider_on = 2,
}



local colors = {
  road = bg(235),
  border = fg(250) .. bg(235),
  divider = fg(220) .. bg(235),
  obstacle = fg(196) .. bg(235),
  player = fg(46) .. bg(235),
}



local ROAD_WIDTH = config.lane_count * config.lane_spacing + 1
local GAME_ROW = 2
local GAME_COL = 2



local function new_game_state()
  return {
    player_lane = 2,
    obstacles = {},
    speed = config.speed_initial,
    distance = 0,
    frame = 0,
    running = true,
  }
end



local function lane_to_column(lane)
  return GAME_COL + (lane - 1) * config.lane_spacing + config.lane_offset
end



local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end



local KEY_DIRECTION = {
  a = -1,
  d = 1,
}



local function handle_input(state)
  local key = read_key(state.speed)
  local dir = KEY_DIRECTION[key]
  if not dir then
    return
  end
  state.player_lane = clamp(state.player_lane + dir, 1, config.lane_count)
end



local function update_obstacles(state)
  local obstacles = state.obstacles
  for i = #obstacles, 1, -1 do
    local o = obstacles[i]
    o.row = o.row + 1
    if o.row > config.road_height then
      obstacles[i] = obstacles[#obstacles]
      obstacles[#obstacles] = nil
    end
  end
end



local function spawn_obstacle(state)
  if math.random() >= config.spawn_rate then
    return
  end
  local lane = math.random(config.lane_count)
  state.obstacles[#state.obstacles + 1] = {
    lane = lane,
    row = 1,
  }
end



local function update_speed(state)
  if state.distance % config.speed_interval ~= 0 then
    return
  end
  state.speed = math.max(config.speed_min, state.speed - config.speed_decay)
end



local function update_game(state)
  update_obstacles(state)
  spawn_obstacle(state)
  state.distance = state.distance + 1
  state.frame = state.frame + 1
  update_speed(state)
end



local function check_collision(state)
  for _, o in ipairs(state.obstacles) do
    if o.row == config.player_row and o.lane == state.player_lane then
      state.running = false
      return
    end
  end
end



local function draw_border(buf)
  buf[#buf + 1] = set_pos(GAME_ROW, GAME_COL)
    .. colors.border
    .. "┌"
    .. string.rep("─", ROAD_WIDTH - 2)
    .. "┐"
    .. RESET_SEQ
end



local function draw_road_row(buf, state, row)
  local screen_row = GAME_ROW + row
  local pos = set_pos(screen_row, GAME_COL)
  buf[#buf + 1] = pos .. colors.road .. string.rep(" ", ROAD_WIDTH) .. RESET_SEQ
  buf[#buf + 1] = pos .. colors.border .. "│" .. RESET_SEQ
  buf[#buf + 1] = set_pos(screen_row, GAME_COL + ROAD_WIDTH - 1) .. colors.border .. "│" .. RESET_SEQ
  if (state.frame + row) % config.divider_period < config.divider_on then
    for lane = 1, config.lane_count - 1 do
      buf[#buf + 1] = set_pos(screen_row, GAME_COL + lane * config.lane_spacing) .. colors.divider .. "┊" .. RESET_SEQ
    end
  end
end



local function draw_obstacles(buf, state, row)
  for _, o in ipairs(state.obstacles) do
    if o.row == row then
      buf[#buf + 1] = set_pos(GAME_ROW + row, lane_to_column(o.lane)) .. colors.obstacle .. "🪨" .. RESET_SEQ
    end
  end
end



local function draw_player(buf, state, row)
  if row ~= config.player_row then
    return
  end
  buf[#buf + 1] = set_pos(GAME_ROW + row, lane_to_column(state.player_lane)) .. colors.player .. "█" .. RESET_SEQ
end



local function draw_road(buf, state)
  draw_border(buf)
  for row = 1, config.road_height do
    draw_road_row(buf, state, row)
    draw_obstacles(buf, state, row)
    draw_player(buf, state, row)
  end

  buf[#buf + 1] = set_pos(GAME_ROW + config.road_height + 1, GAME_COL)
    .. colors.border
    .. "└"
    .. string.rep("─", ROAD_WIDTH - 2)
    .. "┘"
    .. RESET_SEQ
end



local function render(state)
  local buffer = {}
  draw_road(buffer, state)
  buffer[#buffer + 1] = set_pos(GAME_ROW + config.road_height + 3, GAME_COL)
  write(table.concat(buffer))
end



local function clear_screen()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)
end



local function start_screen()
  clear_screen()
  write("\n  CAR RACE\n\n")
  write("  Press [y] to start or [n] to quit\n")
  return read_key(math.huge) == "y"
end



local function game_over_screen(state)
  clear_screen()
  write("\n  GAME OVER\n\n")
  write("  Distance: " .. tostring(state.distance) .. "\n\n")
  write("  Press any key...\n")
  read_key(math.huge)
end



terminal.initwrap(function()
  terminal.cursor.visible.set(false)
  while true do
    if not start_screen() then
      break
    end
    clear_screen()
    local state = new_game_state()
    while state.running do
      handle_input(state)
      update_game(state)
      check_collision(state)
      render(state)
    end

    game_over_screen(state)
  end
end, { displaybackup = true })()
