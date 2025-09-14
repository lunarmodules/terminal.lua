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
    content = Panel.content_border(content_func, terminal.draw.box_fmt.single, ""),
  }
end



-- Example 1: Simple content panel
local function run_example_1()
  terminal.clear.screen()
  terminal.cursor.position.set(1, 1)

  local rows, cols = terminal.size()
  local simple_panel = create_fullscreen_panel(function(row, col, height, width)
    terminal.cursor.position.set(row + 1, col + 1)
    terminal.draw.box(height - 2, width - 2, terminal.draw.box_fmt.single, true, "Simple Panel")
    draw_content(row + 1, col + 1, height - 2, width - 2, "Hello World! Press any key to continue...", "green")
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
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "60% - Press any key", "blue")
        end, terminal.draw.box_fmt.double, "Left Panel"),
      },
      Panel {
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "40%", "red")
        end, terminal.draw.box_fmt.double, "Right Panel"),
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
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "40% - Press any key", "yellow")
        end, terminal.draw.box_fmt.single, "Top Panel"),
      },
      Panel {
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "60%", "magenta")
        end, terminal.draw.box_fmt.single, "Bottom Panel"),
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
            content = Panel.content_border(function(self, row, col, height, width)
              draw_content(row, col, height, width, "30%", "cyan")
            end, terminal.draw.box_fmt.single, "Top Left"),
          },
          Panel {
            content = Panel.content_border(function(self, row, col, height, width)
              draw_content(row, col, height, width, "70%", "green")
            end, terminal.draw.box_fmt.single, "Bottom Left"),
          }
        }
      },
      -- Right side: simple content
      Panel {
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "Full Right - Press any key", "red")
        end, terminal.draw.box_fmt.double, "Right Side"),
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
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "50%", "blue")
        end, terminal.draw.box_fmt.single, "Panel A"),
      },
      Panel {
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "50% - Press any key", "red")
        end, terminal.draw.box_fmt.single, "Panel B"),
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
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "Min: " .. math.max(15, math.floor(cols * 0.3)), "green")
        end, terminal.draw.box_fmt.double, "Min Width"),
      },
      Panel {
        max_width = math.min(20, math.floor(cols * 0.7)), -- Maximum width constraint
        content = Panel.content_border(function(self, row, col, height, width)
          draw_content(row, col, height, width, "Max: " .. math.min(20, math.floor(cols * 0.7)) .. " - Press any key", "red")
        end, terminal.draw.box_fmt.double, "Max Width"),
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
