--- Example usage of the terminal.ui.panel module.
--
-- This example demonstrates how to create and use panels for terminal UI layouts.
-- It shows various panel configurations including content panels, divided panels,
-- and nested layouts.

local terminal = require("terminal")
local Panel = require("terminal.ui.panel")



-- Helper function to draw content in a panel
local function draw_content(row, col, height, width, text, color)
  color = color or "white"

  -- Center the text in the panel
  local text_row = row + math.floor(height / 2)
  local text_col = col + math.floor((width - #text) / 2)

  terminal.cursor.position.set(text_row, text_col)
  terminal.output.write(terminal.text.stack.push_seq({ fg = color }))
  terminal.output.write(text)
  terminal.output.write(terminal.text.stack.pop_seq())
end



-- screen resized checker
local screen_resized do

  local last_rows, last_cols = terminal.size()

  function screen_resized()
    local current_rows, current_cols = last_rows, last_cols
    last_rows, last_cols = terminal.size()
    return current_rows ~= last_rows or current_cols ~= last_cols
  end
end



-- Helper function to create full-screen panel
local function create_fullscreen_panel(content_func)
  return Panel {
    content = content_func,
    border = {
      format = terminal.draw.box_fmt.single,
      title = ""
    }
  }
end



-- Example 1: Simple content panel
local function run_example_1()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local rows, cols = terminal.size()
  local simple_panel = create_fullscreen_panel(function(self, row, col, height, width)
    draw_content(row, col, height, width, "Hello World! Press any key to continue...", "green")
  end)

  simple_panel:calculate_layout(1, 1, rows, cols)
  simple_panel:render()

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      rows, cols = terminal.size()
      simple_panel:calculate_layout(1, 1, rows, cols)
      simple_panel:render()
    end
  end
end


-- Example 2: Horizontal division
local function run_example_2()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local rows, cols = terminal.size()
  local horizontal_panel = Panel {
    orientation = Panel.orientations.horizontal,
    split_ratio = 0.6, -- 60% left, 40% right
    children = {
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "60% - Press any key", "blue")
        end,
        border = {
          format = terminal.draw.box_fmt.double,
          attr = { fg = "blue" },
          title = "Left Panel"
        },
      },
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "40%", "red")
        end,
        border = {
          format = terminal.draw.box_fmt.double,
          attr = { fg = "red" },
          title = "Right Panel"
        },
      }
    }
  }

  horizontal_panel:calculate_layout(1, 1, rows, cols)
  horizontal_panel:render()

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      rows, cols = terminal.size()
      horizontal_panel:calculate_layout(1, 1, rows, cols)
      horizontal_panel:render()
    end
  end
end


-- Example 3: Vertical division
local function run_example_3()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local rows, cols = terminal.size()
  local vertical_panel = Panel {
    orientation = Panel.orientations.vertical,
    split_ratio = 0.4, -- 40% top, 60% bottom
    children = {
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "40% - Press any key", "yellow")
        end,
        border = {
          format = terminal.draw.box_fmt.single,
          attr = { fg = "yellow" },
          title = "Top Panel"
        },
      },
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "60%", "magenta")
        end,
        border = {
          format = terminal.draw.box_fmt.single,
          attr = { fg = "magenta" },
          title = "Bottom Panel"
        },
      }
    }
  }

  vertical_panel:calculate_layout(1, 1, rows, cols)
  vertical_panel:render()

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      rows, cols = terminal.size()
      vertical_panel:calculate_layout(1, 1, rows, cols)
      vertical_panel:render()
    end
  end
end


-- Example 4: Nested panels (complex layout)
local function run_example_4()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  -- create custom formats to connect the panel borders visually
  local fmt_top_left = terminal.draw.box_fmt.copy(terminal.draw.box_fmt.single)
  fmt_top_left.tr = "┬" -- connect to the right panel top left corner
  fmt_top_left.b = ""   -- do not draw the bottom bar (use the lower panels top bar)
  fmt_top_left.bl = fmt_top_left.l  -- no edge, continue vertical line
  fmt_top_left.br = fmt_top_left.l  -- no edge, continue vertical line

  local fmt_bottom_left = terminal.draw.box_fmt.copy(terminal.draw.box_fmt.single)
  fmt_bottom_left.tl = "├"  -- connect to the top panel bottom left corner
  fmt_bottom_left.tr = "┤"  -- connect to the top panel bottom right corner
  fmt_bottom_left.br = "┴"  -- connect to the right panel bottom left corner

  local fmt_right = terminal.draw.box_fmt.copy(terminal.draw.box_fmt.single)
  fmt_right.l = ""    -- do not draw the left border (use the left panels right border)
  fmt_right.tl = fmt_right.t -- no edge, continue horizontal line
  fmt_right.bl = fmt_right.b -- no edge, continue horizontal line


  local rows, cols = terminal.size()
  local nested_panel = Panel {
    orientation = Panel.orientations.horizontal,
    split_ratio = 0.5,
    children = {
      -- Left side: vertical division
      Panel {
        orientation = Panel.orientations.vertical,
        split_ratio = 0.3,
        children = {
          Panel {
            content = function(self, row, col, height, width)
              draw_content(row, col, height, width, "30%", "cyan")
            end,
            border = {
              format = fmt_top_left,
              attr = { fg = "cyan" },
              title = "Top Left"
            },
          },
          Panel {
            content = function(self, row, col, height, width)
              draw_content(row, col, height, width, "70%", "green")
            end,
            border = {
              format = fmt_bottom_left,
              attr = { fg = "green" },
              title = "Bottom Left"
            },
          }
        }
      },
      -- Right side: simple content
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "Full Right - Press any key", "red")
        end,
        border = {
          format = fmt_right,
          attr = { fg = "red" },
          title = "Right Side"
        },
      }
    }
  }

  nested_panel:calculate_layout(1, 1, rows, cols)
  nested_panel:render()

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      rows, cols = terminal.size()
      nested_panel:calculate_layout(1, 1, rows, cols)
      nested_panel:render()
    end
  end
end


-- Example 5: Dynamic resizing
local function run_example_5()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local resizable_panel = Panel {
    orientation = Panel.orientations.horizontal,
    split_ratio = 0.5,
    children = {
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "50%", "blue")
        end,
        border = {
          format = terminal.draw.box_fmt.single,
          attr = { fg = "blue" },
          title = "Panel A"
        },
      },
      Panel {
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "50% - Press any key", "red")
        end,
        border = {
          format = terminal.draw.box_fmt.single,
          attr = { fg = "red" },
          title = "Panel B"
        },
      }
    }
  }

  -- Show different split ratios
  for ratio = 0.2, 0.8, 0.2 do
    terminal.clear.screen()
    terminal.cursor.position.set(1, 1)

    local current_rows, current_cols = terminal.size()
    resizable_panel:set_split_ratio(ratio)
    resizable_panel:calculate_layout(1, 1, current_rows, current_cols)
    resizable_panel:render()

    terminal.cursor.position.set(current_rows - 1, 1)
    terminal.output.write("Split ratio: " .. string.format("%.1f", ratio) .. " - Press any key to continue...")
  end

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      local rows, cols = terminal.size()
      resizable_panel:calculate_layout(1, 1, rows, cols)
      resizable_panel:render()
    end
  end
end


-- Example 6: Size constraints
local function run_example_6()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local rows, cols = terminal.size()
  local constrained_panel = Panel {
    orientation = Panel.orientations.horizontal,
    children = {
      Panel {
        min_width = math.max(15, math.floor(cols * 0.3)), -- Minimum width constraint
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "Min: " .. math.max(15, math.floor(cols * 0.3)), "green")
        end,
        border = {
          format = terminal.draw.box_fmt.double,
          attr = { fg = "green" },
          title = "Min Width"
        },
      },
      Panel {
        max_width = math.min(20, math.floor(cols * 0.7)), -- Maximum width constraint
        content = function(self, row, col, height, width)
          draw_content(row, col, height, width, "Max: " .. math.min(20, math.floor(cols * 0.7)) .. " - Press any key", "red")
        end,
        border = {
          format = terminal.draw.box_fmt.double,
          attr = { fg = "red" },
          title = "Max Width"
        },
      }
    }
  }

  constrained_panel:calculate_layout(1, 1, rows, cols)
  constrained_panel:render()

  while not terminal.input.readansi(0.1) do
    if screen_resized() then
      local rows, cols = terminal.size()
      constrained_panel:calculate_layout(1, 1, rows, cols)
      constrained_panel:render()
    end
  end
end



local function main()
  run_example_1()
  run_example_2()
  run_example_3()
  run_example_4()
  run_example_5()
  run_example_6()
end


-- Wrap main functionality in init+shutdown
main = terminal.initwrap(main, {
  displaybackup = true,
  filehandle = io.stderr
})


main()
print("Panel examples completed!")
